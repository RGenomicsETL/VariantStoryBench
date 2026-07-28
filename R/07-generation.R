bench_validate_capabilities <- function(capabilities) {
  if (!is.data.frame(capabilities)) {
    stop("capabilities must be a data frame", call. = FALSE)
  }
  bench_required_columns(capabilities, c("capability_id", "status", "detail"))
  for (column in c("capability_id", "detail")) {
    bench_nonempty_text(capabilities[[column]], paste0("capabilities$", column))
  }
  bench_choice_values(capabilities$status, c("supported", "unsupported"),
                      "capabilities$status")
  bench_unique_key(capabilities, "capability_id", "capabilities")
  invisible(capabilities)
}

bench_validate_persons <- function(persons, name = "persons") {
  if (!is.data.frame(persons)) {
    stop(name, " must be a data frame", call. = FALSE)
  }
  columns <- c(
    "case_id", "person_id", "vcf_sample_id", "is_proband", "sex", "affected"
  )
  if (!identical(names(persons), columns)) {
    stop(name, " must have exactly columns: ", paste(columns, collapse = ", "),
         call. = FALSE)
  }
  for (column in c("case_id", "person_id", "vcf_sample_id", "sex")) {
    bench_nonempty_text(persons[[column]], paste0(name, "$", column))
  }
  if (!is.logical(persons$is_proband) || anyNA(persons$is_proband)) {
    stop(name, "$is_proband must contain non-missing logical values",
         call. = FALSE)
  }
  bench_choice_values(persons$sex, c("female", "male", "unknown"),
                      paste0(name, "$sex"))
  bench_choice_values(
    persons$affected, c("affected", "unaffected", "unknown"),
    paste0(name, "$affected")
  )
  if (!nrow(persons)) {
    stop(name, " must contain at least one person", call. = FALSE)
  }
  bench_unique_key(persons, c("case_id", "person_id"), name)
  bench_unique_key(persons, c("case_id", "vcf_sample_id"), name)
  proband_counts <- tapply(persons$is_proband, persons$case_id, sum)
  if (any(proband_counts != 1L)) {
    stop(name, " must contain exactly one proband per case", call. = FALSE)
  }
  invisible(persons)
}

bench_validate_relationships <- function(relationships) {
  if (!is.data.frame(relationships)) {
    stop("relationships must be a data frame", call. = FALSE)
  }
  columns <- c("case_id", "person_id", "relative_id", "relationship")
  if (!identical(names(relationships), columns)) {
    stop("relationships must have exactly columns: ",
         paste(columns, collapse = ", "), call. = FALSE)
  }
  for (column in columns) {
    bench_nonempty_text(relationships[[column]], paste0("relationships$", column))
  }
  bench_choice_values(
    relationships$relationship,
    c("biological_parent", "full_sibling", "half_sibling", "partner",
      "consanguineous_partner", "other"),
    "relationships$relationship"
  )
  if (any(relationships$person_id == relationships$relative_id)) {
    stop("a person cannot be related to themselves", call. = FALSE)
  }
  bench_unique_key(relationships, columns, "relationships")
  invisible(relationships)
}

bench_validate_documents <- function(documents) {
  if (!is.data.frame(documents)) stop("documents must be a data frame", call. = FALSE)
  columns <- c("case_id", "document_id", "source_text")
  if (!identical(names(documents), columns)) {
    stop("documents must have exactly columns: ",
         paste(columns, collapse = ", "), call. = FALSE)
  }
  bench_nonempty_text(documents$case_id, "documents$case_id")
  bench_nonempty_text(documents$document_id, "documents$document_id")
  bench_nonempty_text(documents$source_text, "documents$source_text")
  bench_unique_key(documents, "document_id", "documents")
  invisible(documents)
}

bench_validate_hpo_observations <- function(documents, observations) {
  bench_validate_documents(documents)
  contract <- ducksemantics::ducksemantics_hpo_observation_contract()
  wrapper <- c("case_id", "person_id", "observation_id")
  if (!is.data.frame(observations) ||
      !identical(names(observations), c(wrapper, contract))) {
    stop(
      "hpo observations must contain case/person/observation identity around ",
      "the unchanged ducksemantics observation columns",
      call. = FALSE
    )
  }
  for (column in wrapper) {
    bench_nonempty_text(
      observations[[column]], paste0("hpo_observations$", column)
    )
  }
  bench_unique_key(
    observations, c("case_id", "observation_id"), "hpo_observations"
  )
  document_identity <- documents[c("case_id", "document_id")]
  observed_documents <- observations[c("case_id", "document_id")]
  if (nrow(merge(
    observed_documents, document_identity,
    by = c("case_id", "document_id")
  )) != nrow(observed_documents)) {
    stop(
      "every HPO observation must refer to a document in the same case",
      call. = FALSE
    )
  }
  ducksemantics::ducksemantics_hpo_observations(
    documents,
    observations[contract]
  )
  invisible(observations)
}

bench_validate_causal_allele_truth <- function(causal_alleles, truth, alleles) {
  if (!is.data.frame(causal_alleles)) {
    stop("causal_allele_truth must be a data frame", call. = FALSE)
  }
  columns <- c(
    "case_id", "target_type", "causal_id", "record_ordinal", "allele_role",
    "alt_ordinal"
  )
  if (!identical(names(causal_alleles), columns)) {
    stop(
      "causal_allele_truth must have exactly columns: ",
      paste(columns, collapse = ", "), call. = FALSE
    )
  }
  for (column in c("case_id", "target_type", "causal_id", "allele_role")) {
    bench_nonempty_text(
      causal_alleles[[column]], paste0("causal_allele_truth$", column)
    )
  }
  if (any(causal_alleles$target_type != "variant")) {
    stop("causal allele truth currently supports variant targets", call. = FALSE)
  }
  bench_integer_values(
    causal_alleles$record_ordinal, "causal_allele_truth$record_ordinal", 1L
  )
  bench_choice_values(
    causal_alleles$allele_role, c("reference", "alternate"),
    "causal_allele_truth$allele_role"
  )
  alternate <- causal_alleles$allele_role == "alternate"
  if (!is.numeric(causal_alleles$alt_ordinal) || any(alternate &
          (is.na(causal_alleles$alt_ordinal) |
           causal_alleles$alt_ordinal < 1 |
           causal_alleles$alt_ordinal != floor(causal_alleles$alt_ordinal))) ||
      any(!alternate & !is.na(causal_alleles$alt_ordinal))) {
    stop(
      "reference causal alleles require no ALT ordinal; alternate causal ",
      "alleles require a positive ALT ordinal", call. = FALSE
    )
  }
  bench_unique_key(
    causal_alleles, c("case_id", "target_type", "causal_id"),
    "causal_allele_truth"
  )
  variant_truth <- truth[truth$target_type == "variant",
                         c("case_id", "target_type", "causal_id"), drop = FALSE]
  causal_key <- c("case_id", "target_type", "causal_id")
  if (nrow(causal_alleles) != nrow(variant_truth) ||
      nrow(merge(causal_alleles[causal_key], variant_truth, by = causal_key)) !=
        nrow(variant_truth)) {
    stop("causal allele truth must cover exactly variant causal truth",
         call. = FALSE)
  }
  source_records <- unique(alleles[c("case_id", "record_ordinal")])
  if (nrow(merge(
    causal_alleles[!alternate, c("case_id", "record_ordinal"), drop = FALSE],
    source_records, by = c("case_id", "record_ordinal")
  )) != sum(!alternate)) {
    stop("reference causal allele must identify one admitted source record",
         call. = FALSE)
  }
  alternate_key <- c("case_id", "record_ordinal", "alt_ordinal")
  if (nrow(merge(
    causal_alleles[alternate, alternate_key, drop = FALSE],
    alleles[alternate_key], by = alternate_key
  )) != sum(alternate)) {
    stop("alternate causal allele must identify one admitted ALT row",
         call. = FALSE)
  }
  invisible(causal_alleles)
}

bench_validate_inheritance <- function(inheritance, name = "inheritance") {
  if (!is.data.frame(inheritance)) stop(name, " must be a data frame", call. = FALSE)
  bench_required_columns(inheritance, c("case_id", "causal_id", "inheritance"))
  for (column in c("case_id", "causal_id", "inheritance")) {
    bench_nonempty_text(inheritance[[column]], paste0(name, "$", column))
  }
  bench_unique_key(inheritance, c("case_id", "causal_id"), name)
  invisible(inheritance)
}

bench_validate_allele_truth <- function(alleles, name = "allele_truth") {
  if (!is.data.frame(alleles)) stop(name, " must be a data frame", call. = FALSE)
  columns <- c(
    "case_id", "record_ordinal", "alt_ordinal", "assembly", "source_contig",
    "source_position", "source_reference", "source_alternate",
    "canonical_contig", "canonical_position", "canonical_reference",
    "canonical_alternate", "sequence_class", "admission_status"
  )
  if (!identical(names(alleles), columns)) {
    stop(name, " must have exactly columns: ", paste(columns, collapse = ", "),
         call. = FALSE)
  }
  for (column in c(
    "case_id", "assembly", "source_contig", "source_reference",
    "source_alternate", "canonical_contig", "canonical_reference",
    "canonical_alternate", "sequence_class", "admission_status"
  )) {
    bench_nonempty_text(alleles[[column]], paste0(name, "$", column))
  }
  if (any(alleles$assembly != "GRCh38")) {
    stop(name, " must use GRCh38", call. = FALSE)
  }
  for (column in c(
    "record_ordinal", "alt_ordinal", "source_position", "canonical_position"
  )) {
    bench_integer_values(alleles[[column]], paste0(name, "$", column), 1L)
  }
  bench_choice_values(
    alleles$sequence_class, c("SNV", "indel", "CNV"),
    paste0(name, "$sequence_class")
  )
  bench_choice_values(
    alleles$admission_status, c("supported", "routed_symbolic_cnv"),
    paste0(name, "$admission_status")
  )
  if (any((alleles$sequence_class == "CNV") !=
          (alleles$admission_status == "routed_symbolic_cnv"))) {
    stop(name, " CNV class and symbolic routing status conflict", call. = FALSE)
  }
  bench_unique_key(alleles, c("case_id", "record_ordinal", "alt_ordinal"), name)
  invisible(alleles)
}

bench_gt_state <- function(gt, alt_ordinal) {
  if (grepl("/", gt, fixed = TRUE) && grepl("|", gt, fixed = TRUE)) {
    stop("GT cannot mix phased and unphased separators", call. = FALSE)
  }
  alleles <- strsplit(gt, "[/|]")[[1L]]
  if (!length(alleles) || any(!grepl("^([0-9]+|[.])$", alleles))) {
    stop("GT must contain VCF allele indexes or missing alleles", call. = FALSE)
  }
  called <- alleles[alleles != "."]
  status <- if (!length(called)) {
    "no_call"
  } else if (length(called) != length(alleles)) {
    "partial_no_call"
  } else if (any(as.integer(called) == alt_ordinal)) {
    "called_alternate"
  } else if (all(called == "0")) {
    "called_reference"
  } else {
    "other_alternate"
  }
  list(
    ploidy = length(alleles),
    phased = grepl("|", gt, fixed = TRUE),
    call_status = status
  )
}

bench_validate_genotype_truth <- function(genotypes, name = "genotype_truth") {
  if (!is.data.frame(genotypes)) stop(name, " must be a data frame", call. = FALSE)
  columns <- c(
    "case_id", "person_id", "record_ordinal", "alt_ordinal", "gt", "gq",
    "dp", "ploidy", "phased", "call_status"
  )
  if (!identical(names(genotypes), columns)) {
    stop(name, " must have exactly columns: ", paste(columns, collapse = ", "),
         call. = FALSE)
  }
  for (column in c("case_id", "person_id", "gt", "call_status")) {
    bench_nonempty_text(genotypes[[column]], paste0(name, "$", column))
  }
  for (column in c("record_ordinal", "alt_ordinal", "ploidy")) {
    bench_integer_values(genotypes[[column]], paste0(name, "$", column), 1L)
  }
  for (column in c("gq", "dp")) {
    bench_nonnegative_values(
      genotypes[[column]], paste0(name, "$", column), missing = TRUE
    )
    value <- genotypes[[column]]
    if (any(value[!is.na(value)] != floor(value[!is.na(value)]))) {
      stop(name, "$", column, " must contain integer values", call. = FALSE)
    }
  }
  if (!is.logical(genotypes$phased) || anyNA(genotypes$phased)) {
    stop(name, "$phased must contain non-missing logical values", call. = FALSE)
  }
  bench_choice_values(
    genotypes$call_status,
    c("called_alternate", "called_reference", "partial_no_call",
      "no_call", "other_alternate"),
    paste0(name, "$call_status")
  )
  states <- Map(bench_gt_state, genotypes$gt, genotypes$alt_ordinal)
  derived_ploidy <- unname(vapply(states, `[[`, integer(1L), "ploidy"))
  derived_phased <- unname(vapply(states, `[[`, logical(1L), "phased"))
  derived_status <- unname(vapply(states, `[[`, character(1L), "call_status"))
  if (!identical(as.integer(genotypes$ploidy), derived_ploidy) ||
      !identical(genotypes$phased, derived_phased) ||
      !identical(genotypes$call_status, derived_status)) {
    stop(name, " GT conflicts with ploidy, phase, or call status", call. = FALSE)
  }
  bench_unique_key(
    genotypes,
    c("case_id", "person_id", "record_ordinal", "alt_ordinal"), name
  )
  invisible(genotypes)
}

bench_validate_cnv_authority <- function(cnv, name = "cnv") {
  if (!is.data.frame(cnv)) stop(name, " must be a data frame", call. = FALSE)
  columns <- c("case_id", "assembly", "contig", "cnv_type", "start", "end", "authority_id")
  bench_required_columns(cnv, columns)
  for (column in c("case_id", "assembly", "contig", "cnv_type", "authority_id")) {
    bench_nonempty_text(cnv[[column]], paste0(name, "$", column))
  }
  bench_choice_values(cnv$cnv_type, c("DEL", "DUP", "CNV"), paste0(name, "$cnv_type"))
  bench_integer_values(cnv$start, paste0(name, "$start"), minimum = 0L)
  bench_integer_values(cnv$end, paste0(name, "$end"), minimum = 1L)
  if (any(cnv$end <= cnv$start)) {
    stop(name, "$end must be greater than start for BED half-open intervals", call. = FALSE)
  }
  bench_unique_key(cnv, c("case_id", "assembly", "contig", "cnv_type", "start", "end"), name)
  invisible(cnv)
}

bench_cnv_candidate_id <- function(assembly, contig, start, end, cnv_type) {
  paste(assembly, contig, start, end, cnv_type, sep = ":")
}

bench_default_text_provider <- function(presentation) {
  terms <- presentation$phenotype_plan
  term_text <- if (nrow(terms)) {
    paste(
      paste0(terms$hpo_id, " [", terms$context_status, "]"),
      collapse = "; "
    )
  } else {
    "no phenotype terms supplied"
  }
  source_text <- paste0("Synthetic case ", presentation$case_id, ": ", term_text, ".")
  starts <- vapply(
    terms$hpo_id,
    function(hpo_id) regexpr(hpo_id, source_text, fixed = TRUE)[[1L]] - 1L,
    integer(1)
  )
  list(
    source_text = source_text,
    spans = data.frame(
      hpo_id = terms$hpo_id,
      context_status = terms$context_status,
      start_offset = starts,
      end_offset = starts + nchar(terms$hpo_id),
      stringsAsFactors = FALSE
    )
  )
}

bench_description_realization <- function(provider, presentation) {
  if (!is.function(provider)) stop("text_provider must be a function", call. = FALSE)
  value <- provider(presentation)
  if (!is.list(value) || !identical(sort(names(value)), c("source_text", "spans")) ||
      !is.character(value$source_text) || length(value$source_text) != 1L ||
      is.na(value$source_text) || !nzchar(value$source_text) || !is.data.frame(value$spans)) {
    stop("text_provider must return list(source_text =, spans =)", call. = FALSE)
  }
  columns <- c("hpo_id", "context_status", "start_offset", "end_offset")
  bench_required_columns(value$spans, columns)
  for (column in c("hpo_id", "context_status")) {
    bench_nonempty_text(value$spans[[column]], paste0("text_provider spans$", column))
  }
  bench_choice_values(
    value$spans$context_status,
    c("present", "absent/negated", "family_history", "uncertain"),
    "text_provider spans$context_status"
  )
  bench_validate_half_open_spans(
    value$spans$start_offset, value$spans$end_offset, "text provider"
  )
  value
}

bench_hpo_observations_from_text <- function(
    case_id, person_id, document_id, source_text, spans, plan, provider_id) {
  key <- c("hpo_id", "context_status")
  if (nrow(merge(plan[key], spans[key], by = key)) != nrow(plan) ||
      nrow(merge(plan[key], spans[key], by = key)) != nrow(spans)) {
    stop("text_provider spans must map each planned HPO observation exactly once",
         call. = FALSE)
  }
  spans <- spans[match(bench_relation_key(plan, key), bench_relation_key(spans, key)), , drop = FALSE]
  if (!nrow(spans)) {
    return(data.frame(
      case_id = character(),
      person_id = character(),
      observation_id = character(),
      document_id = character(),
      hpo_id = character(),
      start_offset = integer(),
      end_offset = integer(),
      source_text = character(),
      context_status = character(),
      method = character(),
      provider_id = character(),
      provider_version = character(),
      confidence = numeric(),
      status = character(),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    case_id = rep(case_id, nrow(spans)),
    person_id = rep(person_id, nrow(spans)),
    observation_id = paste0(case_id, ":hpo:", seq_len(nrow(spans))),
    document_id = rep(document_id, nrow(spans)),
    hpo_id = spans$hpo_id,
    start_offset = as.integer(spans$start_offset),
    end_offset = as.integer(spans$end_offset),
    source_text = substring(source_text, spans$start_offset + 1L, spans$end_offset),
    context_status = spans$context_status,
    method = rep("synthetic_latent_presentation", nrow(spans)),
    provider_id = rep(provider_id, nrow(spans)),
    provider_version = rep("1", nrow(spans)),
    confidence = rep(1, nrow(spans)),
    status = rep("accepted", nrow(spans)),
    stringsAsFactors = FALSE
  )
}

bench_write_vcf <- function(path, contigs, samples, records, info = FALSE) {
  writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
  closed <- FALSE
  on.exit(if (!closed) writer$close(), add = TRUE)
  writer$addLine("##reference=GRCh38")
  for (contig in contigs) writer$addContig(contig)
  if (info) {
    writer$addINFO("END", "1", "Integer", "End position of the structural variant")
    writer$addINFO("SVTYPE", "1", "String", "Structural variant type")
  }
  writer$addFORMAT("GT", "1", "String", "Genotype")
  writer$addFORMAT("GQ", "1", "Integer", "Genotype quality")
  writer$addFORMAT("DP", "1", "Integer", "Read depth")
  for (sample in samples) writer$addSample(sample)
  for (record in records) writer$writeline(record)
  writer$close()
  closed <- TRUE
  invisible(path)
}

bench_validate_case_truth <- function(cases, truth) {
  bench_validate_cases(cases)
  bench_validate_truth(truth)
  key <- c("case_id", "target_type")
  known <- cases[cases$truth_status == "known_causal", key, drop = FALSE]
  if (nrow(merge(truth, known, by = key)) != nrow(truth) ||
      nrow(merge(known, unique(truth[key]), by = key)) != nrow(known)) {
    stop("evaluator truth must cover exactly known-causal case units", call. = FALSE)
  }
  invisible(TRUE)
}

bench_validate_case_manifest <- function(case_manifest) {
  if (!is.data.frame(case_manifest) ||
      !identical(names(case_manifest), c("case_id", "target_type"))) {
    stop("case_manifest must have exactly columns: case_id, target_type",
         call. = FALSE)
  }
  bench_nonempty_text(case_manifest$case_id, "case_manifest$case_id")
  bench_choice_values(
    case_manifest$target_type, c("variant", "variant_set", "gene", "cnv"),
    "case_manifest$target_type"
  )
  bench_unique_key(case_manifest, c("case_id", "target_type"), "case_manifest")
  invisible(case_manifest)
}

bench_validate_vcf_sample_admission <- function(generations, persons) {
  for (i in seq_len(nrow(generations))) {
    samples <- tryCatch(
      vcfppR::vcftable(generations$vcf_path[[i]])$samples,
      error = function(e) {
        stop("could not read VCF samples for generation ",
             generations$generation_id[[i]], ": ", conditionMessage(e),
             call. = FALSE)
      }
    )
    expected <- persons$vcf_sample_id[persons$case_id == generations$case_id[[i]]]
    if (!setequal(as.character(samples), as.character(expected))) {
      stop(
        "VCF samples must equal persons$vcf_sample_id for generation ",
        generations$generation_id[[i]], call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

bench_validate_engine_input <- function(engine_input) {
  required <- c(
    "case_manifest", "generations", "vcf_paths", "persons",
    "relationships", "documents"
  )
  if (!is.list(engine_input) || !identical(sort(names(engine_input)), sort(required))) {
    stop("engine_input must contain only declared engine-facing relations", call. = FALSE)
  }
  prohibited <- grep("causal|truth|reference|oracle", names(engine_input), value = TRUE)
  relation_columns <- unlist(lapply(
    engine_input[vapply(engine_input, is.data.frame, logical(1))], names
  ), use.names = FALSE)
  prohibited <- c(
    prohibited,
    grep("causal|truth|reference|oracle", relation_columns, value = TRUE)
  )
  if (length(prohibited)) stop("engine_input cannot contain evaluator truth", call. = FALSE)

  bench_validate_case_manifest(engine_input$case_manifest)
  bench_validate_generations(engine_input$generations)
  bench_validate_persons(engine_input$persons)
  bench_validate_relationships(engine_input$relationships)
  bench_validate_documents(engine_input$documents)
  if (!is.character(engine_input$vcf_paths) || anyNA(engine_input$vcf_paths) ||
      !length(engine_input$vcf_paths) ||
      any(!nzchar(engine_input$vcf_paths)) ||
      !all(file.exists(engine_input$vcf_paths))) {
    stop("engine_input$vcf_paths must name existing VCFs", call. = FALSE)
  }

  case_ids <- unique(engine_input$case_manifest$case_id)
  if (!setequal(case_ids, unique(engine_input$generations$case_id)) ||
      !setequal(case_ids, unique(engine_input$persons$case_id)) ||
      !setequal(case_ids, unique(engine_input$documents$case_id))) {
    stop("generations, persons, and documents must cover every case exactly",
         call. = FALSE)
  }
  if (anyDuplicated(engine_input$documents$case_id)) {
    stop("documents must contain exactly one document per case", call. = FALSE)
  }
  if (any(!engine_input$generations$vcf_path %in% unname(engine_input$vcf_paths)) ||
      any(!unname(engine_input$vcf_paths) %in% engine_input$generations$vcf_path)) {
    stop("generations$vcf_path and engine_input$vcf_paths must agree",
         call. = FALSE)
  }

  person_key <- c("case_id", "person_id")
  relationship_people <- unique(rbind(
    engine_input$relationships[person_key],
    data.frame(
      case_id = engine_input$relationships$case_id,
      person_id = engine_input$relationships$relative_id,
      stringsAsFactors = FALSE
    )
  ))
  if (nrow(relationship_people) &&
      nrow(merge(relationship_people, engine_input$persons[person_key],
                 by = person_key)) != nrow(relationship_people)) {
    stop("relationships must refer to declared persons", call. = FALSE)
  }
  bench_validate_vcf_sample_admission(
    engine_input$generations, engine_input$persons
  )
  invisible(engine_input)
}

bench_validate_evaluator_truth <- function(evaluator_truth) {
  required <- c(
    "cases", "truth", "documents", "hpo_observations", "inheritance_truth",
    "allele_truth", "genotype_truth", "causal_allele_truth", "cnv_truth",
    "capabilities"
  )
  if (!is.list(evaluator_truth) || !identical(sort(names(evaluator_truth)), sort(required))) {
    stop("evaluator_truth must contain the declared evaluator-only relations", call. = FALSE)
  }
  bench_validate_case_truth(evaluator_truth$cases, evaluator_truth$truth)
  bench_validate_hpo_observations(
    evaluator_truth$documents, evaluator_truth$hpo_observations
  )
  bench_validate_inheritance(evaluator_truth$inheritance_truth, "inheritance_truth")
  bench_validate_allele_truth(evaluator_truth$allele_truth, "allele_truth")
  bench_validate_genotype_truth(evaluator_truth$genotype_truth, "genotype_truth")
  bench_validate_causal_allele_truth(
    evaluator_truth$causal_allele_truth,
    evaluator_truth$truth,
    evaluator_truth$allele_truth
  )
  bench_validate_cnv_authority(evaluator_truth$cnv_truth, "cnv_truth")
  bench_validate_capabilities(evaluator_truth$capabilities)
  invisible(evaluator_truth)
}

bench_validate_micro_cohort <- function(bundle) {
  if (!is.list(bundle) || !identical(sort(names(bundle)), c("engine_input", "evaluator_truth"))) {
    stop("bundle must contain engine_input and evaluator_truth", call. = FALSE)
  }
  bench_validate_engine_input(bundle$engine_input)
  bench_validate_evaluator_truth(bundle$evaluator_truth)
  bench_generation_relations(
    bundle$evaluator_truth$cases, bundle$evaluator_truth$truth,
    bundle$engine_input$generations
  )
  declared_people <- bundle$engine_input$persons[c("case_id", "person_id")]
  genotype_people <- unique(
    bundle$evaluator_truth$genotype_truth[c("case_id", "person_id")]
  )
  if (nrow(genotype_people) != nrow(declared_people) ||
      nrow(merge(genotype_people, declared_people,
                 by = c("case_id", "person_id"))) != nrow(declared_people)) {
    stop("genotype truth must identify every declared person exactly", call. = FALSE)
  }
  expected_genotypes <- merge(
    bundle$evaluator_truth$allele_truth[
      c("case_id", "record_ordinal", "alt_ordinal")
    ],
    declared_people,
    by = "case_id"
  )
  observed_genotypes <- bundle$evaluator_truth$genotype_truth[
    c("case_id", "record_ordinal", "alt_ordinal", "person_id")
  ]
  genotype_key <- c("case_id", "person_id", "record_ordinal", "alt_ordinal")
  if (nrow(observed_genotypes) != nrow(expected_genotypes) ||
      nrow(merge(observed_genotypes, expected_genotypes, by = genotype_key)) !=
        nrow(expected_genotypes)) {
    stop("genotype truth must cover every person and admitted allele exactly",
         call. = FALSE)
  }
  hpo_people <- unique(
    bundle$evaluator_truth$hpo_observations[c("case_id", "person_id")]
  )
  if (nrow(merge(
    hpo_people, declared_people, by = c("case_id", "person_id")
  )) != nrow(hpo_people)) {
    stop("HPO truth must refer to a declared person in the same case",
         call. = FALSE)
  }
  invisible(bundle)
}

#' Generate a sealed deterministic GRCh38 micro-cohort
#'
#' Writes causal singleton, trio, symbolic-CNV, and confirmed-negative VCF
#' fixtures with `vcfppR`. The returned `engine_input` contains only GRCh38
#' VCFs, person/sample mappings,
#' family presentation, and source documents. `evaluator_truth` is separate and
#' is never supplied to a text provider or engine.
#'
#' `text_provider` receives a case identifier, phenotype/context plan, and
#' relationships. It must return valid source text and a span for every planned
#' HPO observation. Empty phenotype plans produce a valid document with zero
#' observations. The generated observations use the unchanged canonical
#' `ducksemantics` HPO observation contract.
#'
#' @param path Existing or creatable output directory.
#' @param text_provider Function that realizes a clinical source document from
#'   engine-facing presentation data.
#' @param provider_id Declared identity of `text_provider`.
#' @return A list with separate `engine_input` and `evaluator_truth` bundles.
#' @export
bench_generate_micro_cohort <- function(
    path = tempdir(), text_provider = bench_default_text_provider,
    provider_id = "deterministic") {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("path must be one non-empty directory path", call. = FALSE)
  }
  if (!is.character(provider_id) || length(provider_id) != 1L ||
      is.na(provider_id) || !nzchar(provider_id)) {
    stop("provider_id must be one non-empty string", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("could not create path: ", path, call. = FALSE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)

  vcf_paths <- c(
    singleton = file.path(path, "micro-singleton-grch38.vcf.gz"),
    trio = file.path(path, "micro-trio-grch38.vcf.gz"),
    symbolic_cnv = file.path(path, "micro-symbolic-cnv-grch38.vcf.gz"),
    confirmed_negative = file.path(path, "micro-confirmed-negative-grch38.vcf.gz")
  )
  bench_write_vcf(
    vcf_paths[["singleton"]], "1", "MICRO_SINGLETON",
    c(
      "1\t100000\t.\tC\tT\t60\tPASS\t.\tGT:GQ:DP\t0/1:99:36",
      "1\t100100\t.\tTGC\tTC\t60\tPASS\t.\tGT:GQ:DP\t0|1:78:31"
    )
  )
  bench_write_vcf(
    vcf_paths[["trio"]], "2",
    c("MICRO_PROBAND", "MICRO_MOTHER", "MICRO_FATHER"),
    c(
      "2\t199999\t.\tTG\tT\t60\tPASS\t.\tGT:GQ:DP\t0/1:99:42\t0/0:99:39\t0/0:99:40",
      "2\t200100\t.\tT\tA\t60\tPASS\t.\tGT:GQ:DP\t0/1:72:30\t0/0:68:28\t0/0:70:29",
      "2\t200200\t.\tA\tC\t60\tPASS\t.\tGT:GQ:DP\t0/1:18:5\t0/.:.:.\t./.:.:.",
      "2\t200300\t.\tT\tC\t60\tPASS\t.\tGT:GQ:DP\t0/1:8:3\t0/0:7:3\t0/0:8:3"
    )
  )
  bench_write_vcf(
    vcf_paths[["symbolic_cnv"]], "7", "MICRO_CNV_PROBAND",
    "7\t549997\t.\tT\t<DEL>\t60\tPASS\tEND=559997;SVTYPE=DEL\tGT:GQ:DP\t0/1:80:22",
    info = TRUE
  )
  bench_write_vcf(
    vcf_paths[["confirmed_negative"]], "1", "MICRO_NEGATIVE",
    "1\t100000\t.\tC\tG\t60\tPASS\t.\tGT:GQ:DP\t0/1:91:34"
  )

  cnv_id <- bench_cnv_candidate_id("GRCh38", "7", 549997L, 559997L, "DEL")
  cases <- data.frame(
    case_id = c(
      "micro-singleton", "micro-trio", "micro-xcnv", "micro-negative"
    ),
    cohort = "synthetic-micro-grch38",
    target_type = c("variant", "variant", "cnv", "variant"),
    truth_status = c(rep("known_causal", 3L), "confirmed_negative"),
    stringsAsFactors = FALSE
  )
  truth <- data.frame(
    case_id = cases$case_id[1:3],
    target_type = cases$target_type[1:3],
    causal_id = c(
      "GRCh38:1:100000:C:T:REF",
      "GRCh38:2:199999:TG:T:ALT1",
      cnv_id
    ),
    stringsAsFactors = FALSE
  )
  generations <- data.frame(
    case_id = cases$case_id,
    generation_id = c(
      "micro-singleton-vcf", "micro-trio-vcf", "micro-symbolic-cnv-vcf",
      "micro-confirmed-negative-vcf"
    ),
    assembly = "GRCh38",
    vcf_path = unname(vcf_paths),
    case_design = c("singleton", "trio", "symbolic_cnv", "singleton"),
    stringsAsFactors = FALSE
  )
  persons <- data.frame(
    case_id = c(
      "micro-singleton", "micro-trio", "micro-trio", "micro-trio",
      "micro-xcnv", "micro-negative"
    ),
    person_id = c(
      "MICRO_SINGLETON", "MICRO_PROBAND", "MICRO_MOTHER", "MICRO_FATHER",
      "MICRO_CNV_PROBAND", "MICRO_NEGATIVE"
    ),
    vcf_sample_id = c(
      "MICRO_SINGLETON", "MICRO_PROBAND", "MICRO_MOTHER", "MICRO_FATHER",
      "MICRO_CNV_PROBAND", "MICRO_NEGATIVE"
    ),
    is_proband = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE),
    sex = c("male", "male", "female", "male", "female", "unknown"),
    affected = c(
      "affected", "affected", "unaffected", "unaffected", "affected",
      "affected"
    ),
    stringsAsFactors = FALSE
  )
  relationships <- data.frame(
    case_id = c("micro-trio", "micro-trio"),
    person_id = "MICRO_PROBAND",
    relative_id = c("MICRO_MOTHER", "MICRO_FATHER"),
    relationship = c("biological_parent", "biological_parent"),
    stringsAsFactors = FALSE
  )
  phenotype_plan <- data.frame(
    case_id = c(
      "micro-singleton", "micro-singleton", "micro-trio", "micro-trio",
      "micro-negative"
    ),
    hpo_id = c(
      "HP:0001250", "HP:0001252", "HP:0001263", "HP:0001250",
      "HP:0004322"
    ),
    context_status = c(
      "present", "absent/negated", "uncertain", "family_history", "present"
    ),
    stringsAsFactors = FALSE
  )
  # Every case receives a document. The CNV case intentionally has an empty
  # phenotype plan; it still emits a valid note and zero canonical observations.
  documents <- vector("list", nrow(cases))
  observations <- vector("list", nrow(cases))
  document_cases <- cases$case_id
  for (i in seq_along(document_cases)) {
    case_id <- document_cases[[i]]
    plan <- phenotype_plan[phenotype_plan$case_id == case_id,
                           c("hpo_id", "context_status"), drop = FALSE]
    presentation <- list(
      case_id = case_id,
      phenotype_plan = plan,
      relationships = relationships[relationships$case_id == case_id, , drop = FALSE]
    )
    realization <- bench_description_realization(text_provider, presentation)
    document_id <- paste0(case_id, "-note")
    documents[[i]] <- data.frame(
      case_id = case_id,
      document_id = document_id,
      source_text = realization$source_text,
      stringsAsFactors = FALSE
    )
    proband_id <- persons$person_id[
      persons$case_id == case_id & persons$is_proband
    ]
    observations[[i]] <- bench_hpo_observations_from_text(
      case_id, proband_id, document_id, realization$source_text,
      realization$spans, plan, provider_id
    )
  }
  documents <- do.call(rbind, documents)
  hpo_observations <- do.call(rbind, observations)
  inheritance_truth <- data.frame(
    case_id = truth$case_id,
    causal_id = truth$causal_id,
    inheritance = c("unknown", "de_novo", "unknown"),
    stringsAsFactors = FALSE
  )
  allele_truth <- data.frame(
    case_id = c(
      rep("micro-singleton", 2L), rep("micro-trio", 4L), "micro-xcnv",
      "micro-negative"
    ),
    record_ordinal = c(1:2, 1:4, 1, 1),
    alt_ordinal = rep(1L, 8L),
    assembly = rep("GRCh38", 8L),
    source_contig = c(rep("1", 2L), rep("2", 4L), "7", "1"),
    source_position = c(100000L, 100100L, 199999L, 200100L, 200200L,
                        200300L, 549997L, 100000L),
    source_reference = c("C", "TGC", "TG", "T", "A", "T", "T", "C"),
    source_alternate = c("T", "TC", "T", "A", "C", "C", "<DEL>", "G"),
    canonical_contig = c(rep("1", 2L), rep("2", 4L), "7", "1"),
    canonical_position = c(100000L, 100100L, 199999L, 200100L, 200200L,
                           200300L, 549997L, 100000L),
    canonical_reference = c("C", "TG", "TG", "T", "A", "T", "T", "C"),
    canonical_alternate = c("T", "T", "T", "A", "C", "C", "<DEL>", "G"),
    sequence_class = c(
      "SNV", "indel", "indel", "SNV", "SNV", "SNV", "CNV", "SNV"
    ),
    admission_status = c(rep("supported", 6L), "routed_symbolic_cnv", "supported"),
    stringsAsFactors = FALSE
  )
  genotype_truth <- data.frame(
    case_id = c(
      rep("micro-singleton", 2L), rep("micro-trio", 12L), "micro-xcnv",
      "micro-negative"
    ),
    person_id = c(
      "MICRO_SINGLETON", "MICRO_SINGLETON",
      rep(c("MICRO_PROBAND", "MICRO_MOTHER", "MICRO_FATHER"), 4L),
      "MICRO_CNV_PROBAND", "MICRO_NEGATIVE"
    ),
    record_ordinal = c(1L, 2L, rep(1:4, each = 3L), 1L, 1L),
    alt_ordinal = rep(1L, 16L),
    gt = c(
      "0/1", "0|1", "0/1", "0/0", "0/0", "0/1", "0/0", "0/0",
      "0/1", "0/.", "./.", "0/1", "0/0", "0/0", "0/1", "0/1"
    ),
    gq = c(99, 78, 99, 99, 99, 72, 68, 70, 18, NA, NA, 8, 7, 8, 80, 91),
    dp = c(36, 31, 42, 39, 40, 30, 28, 29, 5, NA, NA, 3, 3, 3, 22, 34),
    ploidy = rep(2L, 16L),
    phased = c(FALSE, TRUE, rep(FALSE, 14L)),
    call_status = c(
      "called_alternate", "called_alternate",
      "called_alternate", "called_reference", "called_reference",
      "called_alternate", "called_reference", "called_reference",
      "called_alternate", "partial_no_call", "no_call",
      "called_alternate", "called_reference", "called_reference",
      "called_alternate", "called_alternate"
    ),
    stringsAsFactors = FALSE
  )
  causal_allele_truth <- data.frame(
    case_id = c("micro-singleton", "micro-trio"),
    target_type = "variant",
    causal_id = truth$causal_id[truth$target_type == "variant"],
    record_ordinal = c(1L, 1L),
    allele_role = c("reference", "alternate"),
    alt_ordinal = c(NA_integer_, 1L),
    stringsAsFactors = FALSE
  )
  cnv_truth <- data.frame(
    case_id = "micro-xcnv",
    assembly = "GRCh38",
    contig = "7",
    cnv_type = "DEL",
    start = 549997L,
    end = 559997L,
    authority_id = "XCNV",
    stringsAsFactors = FALSE
  )
  capabilities <- data.frame(
    capability_id = c(
      "micro_vcf_grch38", "symbolic_cnv_transport",
      "reference_causal_allele_orientation", "confirmed_negative_case",
      "realistic_exome_genome", "related_ancestry_admixture",
      "multiplex_consanguinity", "broader_cnv_sv",
      "novel_gene_disease_historical_holdouts"
    ),
    status = c(rep("supported", 4L), rep("unsupported", 5L)),
    detail = c(
      "Synthetic singleton, trio, symbolic-CNV, and negative GRCh38 VCF fixtures.",
      "One symbolic CNV fixture for XCNV transport integration with a proband.",
      "One causal truth row explicitly targets the source REF allele.",
      "One phenotyped case has called ALT alleles but confirmed-negative truth.",
      "No realistic exome or genome simulation is emitted.",
      "No related ancestry or admixture simulation is emitted.",
      "No multiplex or consanguinity simulation is emitted.",
      "No general CNV or SV simulation is emitted.",
      "No novel gene-disease historical holdout cases are emitted."
    ),
    stringsAsFactors = FALSE
  )
  bundle <- list(
    engine_input = list(
      case_manifest = cases[c("case_id", "target_type")],
      generations = generations,
      vcf_paths = vcf_paths,
      persons = persons,
      relationships = relationships,
      documents = documents
    ),
    evaluator_truth = list(
      cases = cases,
      truth = truth,
      documents = documents,
      hpo_observations = hpo_observations,
      inheritance_truth = inheritance_truth,
      allele_truth = allele_truth,
      genotype_truth = genotype_truth,
      causal_allele_truth = causal_allele_truth,
      cnv_truth = cnv_truth,
      capabilities = capabilities
    )
  )
  bench_validate_micro_cohort(bundle)
  bundle
}

#' Evaluate declared results against evaluator-only micro-cohort truth
#'
#' @param evaluator_truth The `evaluator_truth` component from
#'   [bench_generate_micro_cohort()].
#' @param runs,evaluations,candidates Declared engine result relations.
#' @param top_k Positive ranking cutoffs.
#' @return Coverage-aware ranking metrics.
#' @export
bench_evaluate_micro_cohort <- function(
    evaluator_truth, runs, evaluations, candidates,
    top_k = c(1L, 3L, 5L, 10L)) {
  bench_validate_evaluator_truth(evaluator_truth)
  bench_rank_metrics(
    evaluator_truth$cases, evaluator_truth$truth,
    runs, evaluations, candidates, top_k = top_k
  )
}
