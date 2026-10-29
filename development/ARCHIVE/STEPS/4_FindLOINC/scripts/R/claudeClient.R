#
# --- Claude Code client -------------------------------------------------------
#
# A drop-in replacement for the ellmer chat client, backed by the `claude`
# command-line tool (Claude Code) instead of an HTTP provider.
#
# Why a second backend at all
# ---------------------------
# The steps that call an LLM are written against three methods of ellmer's
# chat object -- `set_system_prompt()`, `chat_structured()`, `get_cost()`.
# Anything that offers those three can stand in for it. The `claude` CLI can:
# `--print` runs one non-interactive turn, `--json-schema` constrains the
# answer to a JSON Schema and returns it parsed under `structured_output`, and
# `--output-format json` wraps the whole thing with the run's `total_cost_usd`.
# So the CLI is wrapped here to look like an ellmer client, and the steps
# choose between the two with `--llm claude` / `--llm ellmer` without any
# change to how they build prompts, cache answers, or read them back.
#
# What the wrapper does NOT do
# ----------------------------
# `claude` is an agent, not a bare model endpoint. This wrapper strips it back
# to a single model turn so the two backends are comparable:
#
#   --tools ""                 no tool use: this is a data task, and a run that
#                              could read files would not be reproducible.
#   --system-prompt <prompt>   REPLACES Claude Code's own (large) agent system
#                              prompt with the step's, so the model is given
#                              the same instructions ellmer gives it and
#                              nothing else.
#   --safe-mode                ignores CLAUDE.md, skills, plugins, hooks and MCP
#                              servers, so the answer does not depend on the
#                              checkout's agent configuration. Auth still works.
#   --no-session-persistence   no session written to disk; each group is one
#                              independent turn, exactly as with ellmer.
#
# The schema
# ----------
# The steps declare their output shape once, as an ellmer type object. That
# stays the single source of truth: `ellmerTypeToJsonSchema()` translates it
# into the JSON Schema `--json-schema` wants, so there is no second copy of the
# schema to drift out of step with the first.
#

#
# --- Schema translation -------------------------------------------------------
#
# Translate one ellmer type object into a JSON Schema list (ready for
# jsonlite::toJSON). Every property is marked required and objects are closed
# with additionalProperties = false: structured-output APIs reject open or
# partially-required object schemas, and the steps want every field back
# anyway -- the prompts ask for "" (not a missing key) to mean "cannot tell".
ellmerTypeToJsonSchema <- function(type) {
  description <- tryCatch(type@description, error = function(e) NULL)

  schema <- if (inherits(type, "ellmer::TypeObject")) {
    properties <- lapply(type@properties, ellmerTypeToJsonSchema)
    list(
      type = "object",
      properties = properties,
      required = as.list(names(properties)),
      additionalProperties = FALSE
    )
  } else if (inherits(type, "ellmer::TypeArray")) {
    list(type = "array", items = ellmerTypeToJsonSchema(type@items))
  } else if (inherits(type, "ellmer::TypeEnum")) {
    list(type = "string", enum = as.list(type@values))
  } else if (inherits(type, "ellmer::TypeBasic")) {
    list(type = type@type)
  } else {
    stop("Unsupported ellmer type for the claude backend: ", paste(class(type), collapse = "/"))
  }

  if (!is.null(description) && length(description) == 1 && nzchar(description)) {
    schema$description <- description
  }
  schema
}

#
# --- Client -------------------------------------------------------------------
#
# Returns an object exposing the three methods the steps use. State (the system
# prompt, the cost of the last call) lives in this function's environment, so a
# fresh client per call is genuinely independent -- which is what the parallel
# workers rely on.
makeClaudeClient <- function(config) {
  force(config)
  model <- config$model
  timeoutSec <- suppressWarnings(as.numeric(Sys.getenv("CLAUDE_TIMEOUT_SECONDS", "900")))
  if (is.na(timeoutSec) || timeoutSec <= 0) timeoutSec <- 900

  systemPrompt <- ""
  lastCost <- 0

  chatStructured <- function(prompt, ..., type) {
    schemaJson <- jsonlite::toJSON(ellmerTypeToJsonSchema(type), auto_unbox = TRUE, null = "null")

    # The user message goes in on stdin rather than as an argv element: a group
    # table plus its candidate list is tens of kilobytes and argv is capped
    # (ARG_MAX). The system prompt and schema stay as arguments -- they are
    # bounded, and `claude` has no file form for either.
    promptFile <- tempfile(fileext = ".txt")
    on.exit(unlink(promptFile), add = TRUE)
    writeLines(paste(prompt, collapse = "\n"), promptFile)

    args <- c(
      "--print",
      "--model", model,
      "--output-format", "json",
      "--json-schema", as.character(schemaJson),
      "--tools", "",
      "--safe-mode",
      "--no-session-persistence"
    )
    if (nzchar(systemPrompt)) args <- c(args, "--system-prompt", systemPrompt)

    # error_on_status = FALSE so a non-zero exit is turned into an R error here,
    # with the CLI's own stderr in the message -- the callers all wrap this in a
    # tryCatch/retry loop and log whatever message comes out.
    run <- processx::run("claude", args, stdin = promptFile,
                         error_on_status = FALSE, timeout = timeoutSec)
    if (run$status != 0) {
      stop("claude exited with status ", run$status, ": ",
           substr(paste(run$stderr, run$stdout), 1, 2000))
    }

    parsed <- tryCatch(
      jsonlite::fromJSON(run$stdout, simplifyVector = FALSE),
      error = function(e) stop("claude returned output that is not JSON: ",
                               substr(run$stdout, 1, 2000))
    )
    if (isTRUE(parsed$is_error)) {
      stop("claude reported an error: ", substr(as.character(parsed$result), 1, 2000))
    }

    cost <- suppressWarnings(as.numeric(parsed$total_cost_usd))
    lastCost <<- if (length(cost) == 0 || is.na(cost)) 0 else cost

    # `structured_output` is the schema-validated answer. Fall back to parsing
    # `result` (the raw text) only if it is absent -- which happens when the
    # model answered without going through the structured-output tool.
    if (!is.null(parsed$structured_output)) return(parsed$structured_output)
    fallback <- tryCatch(
      jsonlite::fromJSON(as.character(parsed$result), simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(fallback)) {
      stop("claude returned no structured output: ", substr(as.character(parsed$result), 1, 2000))
    }
    fallback
  }

  list(
    set_system_prompt = function(prompt) {
      systemPrompt <<- paste(prompt, collapse = "\n")
      invisible(NULL)
    },
    chat_structured = chatStructured,
    get_cost = function() lastCost
  )
}
