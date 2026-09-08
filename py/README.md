# Patent-Based Digital Transformation Measure

This folder provides concise materials documenting the construction of the patent-based digital-transformation measure used in the study. It includes the final feature dictionary, the patent-classification rules, and code that implements the retained LDA--Word2Vec classification workflow.

## Files

| File | Description |
| --- | --- |
| `construct_digital.py` | Fits the reported LDA specification, classifies patents using a locally available Word2Vec model, and writes firm-year digital patent counts. |
| `materials/final_feature_dictionary.txt` | Final 70-term digital-technology feature lexicon. |
| `materials/lda_topic_outputs.csv` | Reported top-10 words and lexical similarity for the five global LDA topics. |
| `classification_rules.md` | Lexicon-screening, topic-selection, and patent-classification rules. |
| `requirements.txt` | Python packages used by the script. |

## Data and model availability

The repository does not include raw or processed patent records, CNRDS/CSMAR data, the Word2Vec training corpus, or Word2Vec model files. Users must obtain the relevant licensed data independently and provide a locally available Word2Vec model. The original model-training software environment was not retained; accordingly, these materials document the retained workflow and inputs without claiming exact regeneration of every historical intermediate output.

## Required patent-data fields

The input CSV must include the following columns. The script uses only the first, sixth, and seventh fields; the remaining patent fields may be retained for users' own data management.

| Input field | Role in the script |
| --- | --- |
| `股票代码` | Firm identifier; written as `firm_id` in the output. |
| `专利申请年份` | Patent application year; written as `year` in the output. |
| `processed` | Preprocessed, space-separated patent-abstract tokens. |

The supplied input may also contain `专利类型`, `IPC分类号`, `专利申请号`, and `申请公布号`.

## How to run

1. Install the packages:

   ```bash
   pip install -r requirements.txt
   ```

2. Place a licensed patent CSV outside the repository and retain the Word2Vec model and its companion files in a local directory.

3. Run the construction script, replacing each placeholder with a local path:

   ```bash
   python construct_digital.py \
     --patent-csv /path/to/patents_processed.csv \
     --feature-dictionary materials/final_feature_dictionary.txt \
     --word2vec-model /path/to/word2vec.model \
     --output output/firm_year_digital_patent_counts.csv \
     --topic-output output/lda_topic_outputs.csv
   ```

4. Merge `firm_year_digital_patent_counts.csv` into the licensed firm-year panel. Assign zero to firm-years with no matching digital patents, then calculate `digital = ln(1 + digital_patent_count)`.

5. Run the Stata scripts in the accompanying empirical-analysis folder: `00_config.do`, `01_main_analyses.do`, and `02_appendix_analyses.do`.

## Resource note

The script fits LDA on the supplied patent corpus and therefore may require substantial memory for a full patent sample. Large patent files, Word2Vec model files, training corpora, and patent-level classification outputs are intentionally not included in this repository.
