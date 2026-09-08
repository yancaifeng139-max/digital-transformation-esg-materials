"""Construct the patent-based digital-transformation measure.

This script documents the retained measurement workflow used in the study.
It (i) fits a five-topic LDA model to preprocessed invention-patent abstracts,
(ii) selects the three most probable topics for each patent, (iii) compares
the resulting topic-keyword set with the final 70-term feature lexicon using
average Word2Vec vectors and cosine similarity, and (iv) aggregates digital
patents to the firm-year level.

No commercial patent data, Word2Vec training corpus, or Word2Vec model is
distributed with this repository. See README.md before running this script.
"""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
from gensim import corpora, models
from gensim.models import Word2Vec
from sklearn.metrics.pairwise import cosine_similarity
from tqdm import tqdm


DEFAULT_FIRM_COLUMN = "股票代码"
DEFAULT_YEAR_COLUMN = "专利申请年份"
DEFAULT_TEXT_COLUMN = "processed"


def read_feature_dictionary(path: Path) -> list[str]:
    """Read the one-term-per-line final feature lexicon."""
    terms = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    terms = [term for term in terms if term]
    if len(terms) != len(set(terms)):
        raise ValueError("The feature dictionary contains duplicate terms.")
    return terms


def normalise_firm_id(value: object) -> str:
    """Preserve string identifiers and remove an accidental trailing '.0'."""
    text = str(value).strip()
    if text.endswith(".0") and text[:-2].isdigit():
        return text[:-2]
    return text


def mean_vector(tokens: list[str], keyed_vectors) -> np.ndarray | None:
    vectors = [keyed_vectors[token] for token in tokens if token in keyed_vectors]
    if not vectors:
        return None
    return np.mean(vectors, axis=0).reshape(1, -1)


def cosine_similarity_of_sets(
    patent_terms: list[str], feature_terms: list[str], keyed_vectors
) -> float:
    """Return cosine similarity between the two sets' average Word2Vec vectors."""
    patent_vector = mean_vector(patent_terms, keyed_vectors)
    feature_vector = mean_vector(feature_terms, keyed_vectors)
    if patent_vector is None or feature_vector is None:
        return 0.0
    return float(cosine_similarity(patent_vector, feature_vector)[0, 0])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Classify digital patents and aggregate digital patent counts by firm-year."
    )
    parser.add_argument("--patent-csv", required=True, type=Path)
    parser.add_argument("--feature-dictionary", required=True, type=Path)
    parser.add_argument("--word2vec-model", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--topic-output", required=True, type=Path)
    parser.add_argument("--firm-column", default=DEFAULT_FIRM_COLUMN)
    parser.add_argument("--year-column", default=DEFAULT_YEAR_COLUMN)
    parser.add_argument("--text-column", default=DEFAULT_TEXT_COLUMN)
    parser.add_argument("--min-year", type=int, default=2010)
    parser.add_argument("--max-year", type=int, default=2023)
    parser.add_argument("--num-topics", type=int, default=5)
    parser.add_argument("--top-topics-per-patent", type=int, default=3)
    parser.add_argument("--top-words-per-topic", type=int, default=10)
    parser.add_argument("--similarity-threshold", type=float, default=0.8)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    required_columns = [args.firm_column, args.year_column, args.text_column]

    patents = pd.read_csv(args.patent_csv, usecols=required_columns, dtype={args.firm_column: "string"})
    patents[args.year_column] = pd.to_numeric(patents[args.year_column], errors="coerce")
    patents = patents.loc[
        patents[args.year_column].between(args.min_year, args.max_year)
        & patents[args.text_column].notna()
    ].copy()
    patents[args.text_column] = patents[args.text_column].astype(str).str.strip()
    patents = patents.loc[patents[args.text_column].ne("")].copy()
    if patents.empty:
        raise ValueError("No usable patent records remain after the stated filters.")

    patents["firm_id"] = patents[args.firm_column].map(normalise_firm_id)
    patents["year"] = patents[args.year_column].astype(int)
    texts = [text.split() for text in patents[args.text_column]]

    # LDA specification reported in Appendix III.
    dictionary = corpora.Dictionary(texts)
    dictionary.filter_extremes(no_below=10, no_above=0.5, keep_n=50_000)
    corpus = [dictionary.doc2bow(text) for text in texts]
    lda_model = models.LdaModel(
        corpus=corpus,
        id2word=dictionary,
        num_topics=args.num_topics,
        passes=10,
        random_state=42,
    )

    # Save only topic-level output, not patent-level commercial data.
    topic_rows = []
    for topic_id in range(args.num_topics):
        for rank, (term, weight) in enumerate(
            lda_model.show_topic(topic_id, topn=args.top_words_per_topic), start=1
        ):
            topic_rows.append(
                {"topic_id": topic_id + 1, "rank": rank, "term": term, "weight": weight}
            )
    args.topic_output.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(topic_rows).to_csv(args.topic_output, index=False, encoding="utf-8-sig")

    feature_terms = read_feature_dictionary(args.feature_dictionary)
    if len(feature_terms) != 70:
        raise ValueError(
            f"The final feature dictionary must contain 70 unique terms; found {len(feature_terms)}."
        )
    keyed_vectors = Word2Vec.load(str(args.word2vec_model)).wv

    # The final output retains all firm-years with at least one usable patent;
    # firm-years without a classified digital patent receive a count of zero.
    digital_counts: Counter[tuple[str, int]] = Counter()
    for bow, firm_id, year in tqdm(
        zip(corpus, patents["firm_id"], patents["year"]),
        total=len(patents),
        desc="Classifying patents",
    ):
        document_topics = lda_model.get_document_topics(bow)
        selected_topic_ids = [
            topic_id
            for topic_id, _ in sorted(document_topics, key=lambda item: -item[1])[ : args.top_topics_per_patent]
        ]
        patent_terms: set[str] = set()
        for topic_id in selected_topic_ids:
            patent_terms.update(
                term for term, _ in lda_model.show_topic(topic_id, topn=args.top_words_per_topic)
            )
        similarity = cosine_similarity_of_sets(list(patent_terms), feature_terms, keyed_vectors)
        if similarity >= args.similarity_threshold:
            digital_counts[(firm_id, year)] += 1

    all_firm_years = patents[["firm_id", "year"]].drop_duplicates()
    output = all_firm_years.copy()
    output["digital_patent_count"] = [
        digital_counts[(firm_id, year)]
        for firm_id, year in zip(output["firm_id"], output["year"])
    ]
    output["digital_patent_count"] = output["digital_patent_count"].astype(int)
    output = output.sort_values(["firm_id", "year"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(args.output, index=False, encoding="utf-8-sig")
    print(f"Saved firm-year digital patent counts to: {args.output}")
    print(f"Saved topic-level output to: {args.topic_output}")


if __name__ == "__main__":
    main()
