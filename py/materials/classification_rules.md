# Patent Classification Rules

## Purpose

The patent-based measure captures firms' digital-technology innovation output. It does not attempt to measure all forms of corporate digital transformation, such as purchased software, outsourced digital services, or non-patented organisational applications.

## Feature lexicon

The final feature lexicon contains 70 terms and is provided in `materials/final_feature_dictionary.txt`. Candidate expansion terms were retained only when their cosine similarity to the corresponding seed term exceeded 0.8. Each retained candidate was then subject to bidirectional semantic validation: the corresponding seed term had to appear in the candidate term's nearest-neighbour list. The candidates that passed these filters were manually reviewed, and terms that did not effectively represent digital technologies in the patent context were removed. The retained terms were combined with the applicable seed terms and deduplicated to form the reported final lexicon.

## LDA specification

The analysis retains invention-patent records from 2010 to 2023 with nonmissing preprocessed abstracts. A dictionary is constructed from the tokenised abstracts after removing words appearing in fewer than 10 documents or in more than 50% of documents, with the vocabulary capped at 50,000 terms. The LDA model uses five topics, 10 passes, and `random_state=42`.

For each patent, the three topics with the highest posterior probabilities are retained. The ten highest-weighted words from each selected topic are pooled and deduplicated to obtain the patent keyword set.

## Digital-patent decision rule

For each patent, average Word2Vec vectors are calculated separately for (i) the patent keyword set and (ii) the final 70-term feature lexicon. The cosine similarity between the two average vectors is then calculated. A patent is classified as a digital patent when the similarity is greater than or equal to 0.8.

## Firm-year aggregation

Digital patents are aggregated by firm and patent application year to obtain `digital_patent_count`. This count is merged into the licensed firm-year panel, and firm-years with no digital patents are assigned zero. The explanatory variable is then constructed as `digital = ln(1 + digital_patent_count)`.

## Word2Vec training configuration

The retained method used a Skip-Gram Word2Vec model with vector size 128, window size 6, minimum word frequency 5, five negative samples, and six training epochs. The original training corpus comprised preprocessed Chinese Wikipedia and Sogou materials. The training corpus and model files are not distributed in this repository.
