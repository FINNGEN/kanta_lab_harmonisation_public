library(dplyr)
library(ellmer)
library(gargle)

Sys.setenv(GOOGLE_APPLICATION_CREDENTIALS = '/Users/javier/keys/atlas-development-270609-410deaacc58b.json')

source("tests/manualtest/hack.R")

chat  <- chat_google_vertex(
  location = "europe-north1",
  project_id = "atlas-development-270609",
  system_prompt = NULL,
  model = "gemini-2.5-pro"
)

response <- chat$chat("Say 'Hello from non-interactive R!'")
live_console(chat)




summary  <- readr::read_tsv("tests/manualtest/lab_data_summary.csv", na = "")
summary |> glimpse()


summary  <- readr::read_tsv("tests/manualtest/lab_data_summary.csv", na = "")
finnish_code <- summary |> dplyr::pull(testId) |> head(1)

prompt <- interpolate_file(
    path = "tests/manualtest/prompt.md",
    finnish_code = finnish_code
)

output_structure <- type_object(
  .description = "Extract list of ingredients ",
  isPanel = type_boolean(description = "True if the test is a panel, false otherwise."),
  System = type_string(description = "The system where the measurement is made."),
  Component = type_string(description = "The component being examined."),
  Quantity = type_string(description = "How the result is expressed."),
  Summary = type_string(description = "A brief summary of the test and the reasons for its classification.")
)

structured_recipe <- chat$chat_structured(
  prompt,
  type = output_structure
)


print(structured_recipe)
chat$get_cost()



# Parallel 
set.seed(13)

summary_n   <-  summary |>
select(status, OMOP_CONCEPT_ID, concept_name, omopQuantity, testId) |>
dplyr::filter(status == "APPROVED") |>
dplyr::sample_n(10) 

prompts <- interpolate_file(
    path = "tests/manualtest/prompt.md",
    finnish_code = summary_n$testId
)

response  <- parallel_chat_structured(
    chat = chat,
    prompts = prompts,
    type = output_structure
)



bind_cols(summary_n, response |> as_tibble()) |>
transmute(testId, concept_name, loinc, yes = (concept_name==loinc), components, no_loinc, summary)  |> 
View()



