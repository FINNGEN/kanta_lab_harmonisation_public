########################################
#### CURRENT FILE: ON START SCRIPT #####
########################################

## activate renv and install usethis
renv::init()
renv::install("usethis")
renv::install("tidyverse")

usethis::use_mit_license()

## Create Common Files ----
## See ?usethis for more information
usethis::use_readme_rmd( open = FALSE )
#usethis::use_code_of_conduct()
usethis::use_lifecycle_badge( "Experimental" )
usethis::use_news_md( open = FALSE )

## Use git ----
usethis::use_git()
usethis::use_github(private = FALSE)

