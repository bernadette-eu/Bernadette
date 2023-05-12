# Contact matrix -------------------------

# Path
giturl <- paste0("https://raw.github.com/",
                 "kieshaprem/synthetic-contact-matrices/",
                 "master/output/",
                 "syntheticcontactmatrices2020/overall/",
                 "contact_all.rdata")

# Import the list of 16x16 tables:
load(url(giturl))

contact_matrices <- contact_all

# Export:
usethis::use_data(contact_matrices, overwrite = TRUE)
