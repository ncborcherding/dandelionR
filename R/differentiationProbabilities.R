#' Compute Branch Probabilities Using Markov Chain
#'
#' This function calculates branch probabilities for differentiation trajectories based on a Markov chain constructed from waypoint data and pseudotime ordering.
#'
#' @param wp_data A multi-scale data matrix or data frame representing the waypoints.
#' @param terminal_states Integer vector. Indices of the terminal states. Default is `NULL`.
#' @param knn Integer. Number of nearest neighbors for graph construction. Default is `30L`.
#' @param pseudotime Numeric vector. Pseudotime ordering of cells.
#' @param waypoints Integer vector. Indices of selected waypoints used to construct the Markov chain.
#' @return A numeric matrix or data frame containing branch probabilities for each waypoint.
#' @importFrom Matrix solve
#' @importFrom MASS ginv
#' @include constructMarkovChain.R
#' @include terminalStateFromMarkovChain.R
differentiationProbabilities <- function(
    wp_data, terminal_states = NULL, knn = 30L,
    pseudotime, waypoints) {
    T_ <- .constructMarkovChain(wp_data, knn, pseudotime, waypoints)
    # identify terminal states if not specified
    if (is.null(terminal_states)) {
        terminal_states <- .terminalStateFromMarkovChain(
            T_, wp_data, pseudotime,
            waypoints
        )
    }
    abs_states_idx <- which(waypoints %in% terminal_states)
    T_[abs_states_idx, ] <- 0
    T_ <- Reduce(function(matri, x) {
        matri[x, x] <- 1
        matri
    }, x = abs_states_idx, init = T_)
    message("Computing fundamental matrix and absorption probabilities...")
    # Transition states
    trans_states_idx <- which(!(waypoints %in% terminal_states))
    # Q matrix
    Q <- T_[-abs_states_idx, -abs_states_idx]
    # Fundamental matrix
    mat <- diag(dim(Q)[[1]]) - Q
    N <- tryCatch(
        {
            solve(mat)
        },
        error = function(cnd) {
            warning("Matrix generated is singular or nearly singular; using pseudo-inverse to construct fundamental matrix")
            warning("Or you can re-run this function to reconstruct the markov chain")
            ginv(as.matrix(mat))
        }
    )
    R <- T_[trans_states_idx, abs_states_idx]
    # absorbing probabilities:
    probabilities <- N %*% R
    probabilities@x[probabilities@x < 0] <- 0
    # add terminal states
    probabilities <- rbind(probabilities, T_[abs_states_idx, abs_states_idx])
    probabilities <- probabilities[order(c(trans_states_idx, abs_states_idx)), ]
    return(probabilities)
}
