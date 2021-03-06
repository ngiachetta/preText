#' @title Calculate mean prediction error for preprocessing decisions.
#' @description Use scaled positions to predict preprocessing decisions.
#'
#' @param positions_list A list of scaled document positions generated by the
#' `scaling_comparison()` functions and returned from that function in the
#' `$scaled_positions` slot in the list object.
#' @param preprocessing_choices A data frame containing binary indicators of
#' whether each preprocessing decision was applied for each dfm. This is returned
#' by the `factorial_preprocessing()` function as part of its output.
#' @return A vector of mean prediction errors.
#' @examples
#' \dontrun{
#' # *** This function is used automatically inside of the preText() function.
#' # load the package
#' library(preText)
#' # load in the data
#' data("UK_Manifestos")
#' # preprocess data
#' preprocessed_documents <- factorial_preprocessing(
#'     UK_Manifestos,
#'     use_ngrams = TRUE,
#'     infrequent_term_threshold = 0.02,
#'     verbose = TRUE)
#' # scale documents
#' scaling_results <- scaling_comparison(preprocessed_documents$dfm_list,
#'                                       dimensions = 2,
#'                                       distance_method = "cosine",
#'                                       verbose = TRUE)
#' # get prediction errors
#' pred_errors <- calculate_prediction_errors(
#'      scaling_results$scaled_positions,
#'      preprocessed_documents$choices)
#' }
#' @export
calculate_prediction_errors <- function(positions_list,
                                        preprocessing_choices){

    # get the number of dfms
    num_dfms <- length(positions_list)
    num_steps <- ncol(preprocessing_choices)
    # get anchor scaled psoitions
    anchor_positions <- positions_list[[1]]
    anchor_positions <- anchor_positions[order(rownames(anchor_positions)),]
    document_names <- rownames(anchor_positions)
    ndoc <- length(document_names)

    document_position_data <- vector(mode = "list", length = ndoc)

    for(j in 1:ndoc) {
        curdata <- data.frame(x = rep(0,num_dfms),
                              y = rep(0,num_dfms))
        curdata[1,] <- anchor_positions[j,]

        document_position_data[[j]] <- curdata
    }

    # rotate the other positions and put them together in a big data.frame
    for (i in 2:num_dfms) {
        cur_pos <- positions_list[[i]][order(rownames(positions_list[[i]])),]
        cur <- vegan::procrustes(anchor_positions,
                                 cur_pos,
                                 scale = F)$Yrot

        for(j in 1:ndoc) {
            document_position_data[[j]][i,] <- cur[j,]
        }
    }


    classification_errors <- matrix(0, ncol = num_steps, nrow = ndoc)

    for(i in 1:ndoc) {
        temp <- document_position_data[[i]]
        for (j in 1:num_steps) {
            data <- data.frame(outcome = preprocessing_choices[,j],
                               x = temp$x,
                               y = temp$y,
                               stringsAsFactors = FALSE)

            fit <- stats::glm(formula = outcome ~ x + y,
                              data = data,
                              family = "binomial")

            predictions <- round(stats::predict(fit,type = "response"))

            error_rate <- length(which(data$outcome != predictions))/num_dfms

            classification_errors[i,j] <- error_rate
        }
    }

    mean_ce <- colMeans(classification_errors)
    mean_sd <- apply(classification_errors,2,sd)
    mean_ub <- 1.96*mean_sd + mean_ce
    significant <- mean_ub < 0.5

    mean_ce_data <- data.frame(mean_classification_error = mean_ce,
                               classification_error_sd = mean_sd,
                               CE_upper_bound = mean_ub,
                               significant = significant,
                               stringsAsFactors = FALSE)

    colnames(classification_errors) <- colnames(preprocessing_choices)
    names(mean_ce) <- colnames(preprocessing_choices)
    rownames(classification_errors) <- document_names
    rownames(mean_ce_data) <- colnames(preprocessing_choices)

    classification_errors <- as.data.frame(classification_errors)

    cat("Mean classification errors for each preprocessing decision:\n\n")
    print(mean_ce)

    return(list(mean_classifcation_error = mean_ce,
                mean_classifcation_error_stats = mean_ce_data,
                document_classification_errors = classification_errors))
}

