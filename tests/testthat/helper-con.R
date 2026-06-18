# Open a memory connection that is closed at the end of the calling test.
local_con <- function(env = parent.frame(), ...) {
  con <- suppressMessages(duckr_connect(...))
  withr::defer(suppressMessages(duckr_close(con)), envir = env)
  con
}
