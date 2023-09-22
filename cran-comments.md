
# Version 1.1.5

2023-09-13

This is a resubmission. In this version I have updated deprecated syntax for future rstan compatibility:

* DESCRIPTION: requires rstan >= 2.26.0 & StanHeaders >= 2.26.0.

* Function inst/stan/igbm.stan: 'real' data types are declared by 'array[] real'.

# Version 1.1.4

2023-06-06

This is a resubmission. In this version I have:

* Function inst/stan/igbm.stan: enabled the end-user to change the granularity of the effective contact rate within a time-span of seven days.
* Function R/stan_igbm.fit.R: performed calculations that are passed to the inst/stan/igbm.stan model.
* Function R/stan_igbm.R: added an indicator to control the granularity of the effective contact rate.

Examples has been checked.

# Version 1.1.3

2023-05-29

This is a resubmission. In this version I have:

* Function R/stan_igbm.fit.R: removed code line 'out$stanfit <- suppressMessages(rstan::sampling(stanfit, data = standata, chains = 0))'.
* Functions R/posterior_.R: added a stopping rule that tries to locate "theta_tilde" in 'names(object)', which can only be found in the object returned by rstan::optimizing(). A message is shown, instructing the user to perform Markov chain Monte Carlo sampling using rstan::sampling() or rstan::vb().
* Ensured that no more than 2 cores are used in the examples.
* Ensured that the examples are executable in < 5 sec.

# Version 1.1.2

2023-05-25

This is a resubmission. In this version I have:

* Debugged functions R/stan_igbm.fit.R, R/stan_igbm.R and R/summary.stangbm.R.
* Debugged the R/posterior_.R functions.

# Version 1.1.1

# Round 2

2023-05-17

## Test environments

* Local:
  - Windows 10, R 4.2.2 (x86_64-w64-mingw32/x64 (64-bit))
* macOS builder (https://mac.r-project.org/)
* R-hub builder (https://builder.r-hub.io/)

## CRAN comments

> Please add \\value to .Rd files regarding exported methods and explain the functions results in the documentation. Please write about the structure of the output (class) and also what the output means. (If a function does not return a value, please document that too, e.g. \\value{No return value, called for side effects}' or similar)
Missing Rd-tags:
      country_contact_matrices.Rd: \\value
      stan_igbm.Rd: \\value
      summary.stanigbm.Rd: \\value

Added `\value` to all exported functions.

> \\dontrun{} should only be used if the example really cannot be executed (e.g. because of missing additional software, missing API keys, ...) by the user. That's why wrapping examples in \\dontrun{} adds the comment ("# Not run:") as a warning for the user. Does not seem necessary. Please unwrap the examples if they are executable in < 5 sec, or create additionally small toy examples to allow automatic testing. (You could also replace \\dontrun{} with \\donttest{}, if it takes longer than 5 sec to be executed, but it would be preferable to have automatic checks for functions. Otherwise, you can also write some tests.)

The examples that are executable in < 5 sec have been unwrapped. For the examples that are executable in > 5 sec, `\dontrun{}` was replaced with `\donttest{}`.

> Please ensure that you do not use more than 2 cores in your examples, vignettes, etc.

Done.

# Round 1

2023-05-16

## Submission comments

> Not more than 5MB for a CRAN package, please.

This has been addressed and the size of the tarball is now < 5MB.

> Is there some reference about the method you can add in the Description field in the form Authors (year) <doi:10.....> or <arXiv:.....>?

A reference about the method has been added in the Description field in the form "Authors (year) <arXiv:.....>".

## Test environments

* Local:
  - Windows 10, R 4.2.2 (x86_64-w64-mingw32/x64 (64-bit))
* macOS builder (https://mac.r-project.org/macbuilder/results/1684151644-59dd962bb20e410f/)
* R-hub builder (https://builder.r-hub.io)
  - Windows Server 2022 R-devel, 64 bit
    - NOTE 1 - **A reference about the method has been added in the Description field in the form "Authors (year) <arXiv:.....>".**
      ```
      * checking CRAN incoming feasibility ... [13s] NOTE
      
      New submission
      
      Possibly misspelled words in DESCRIPTION:
        Bouranis (15:75)
        Demiris (16:5)
        Kalogeropoulos (16:17)
        Ntzoufras (16:40)
      Maintainer: 'Lampros Bouranis <bernadette.aueb@gmail.com>'
      ```
    - NOTE 2 - **This note is unrelated to the Bernadette package.**
    
      ```
      * checking HTML version of manual ... NOTE
      Skipping checking math rendering: package 'V8' unavailable
      ```
    - NOTE 3 - **This is a Windows-related note.**
      ```
      * checking for non-standard things in the check directory ... NOTE
      Found the following files/directories:
      ''NULL''
      ```
    - NOTE 4 - **Following [R-hub issue #503](https://github.com/r-hub/rhub/issues/503), this could be due to a bug/crash in MiKTeX and can likely be ignored.**
    
      ```
      * checking for detritus in the temp directory ... NOTE
      Found the following files/directories:
      'lastMiKTeXException'
      ```
  - Ubuntu Linux 20.04.1 LTS, R-release, GCC 
    - NOTE 1 - **A reference about the method has been added in the Description field in the form "Authors (year) <arXiv:.....>".**
      ```
      * checking CRAN incoming feasibility ... [5s/15s] NOTE
      Maintainer: ‘Lampros Bouranis <bernadette.aueb@gmail.com>’
      
      New submission
      
      Possibly misspelled words in DESCRIPTION:
        Bouranis (15:75)
        Demiris (16:5)
        Kalogeropoulos (16:17)
        Ntzoufras (16:40)
      ```
    - NOTE 2:
      
      ```
      * checking installed package size ... NOTE
      installed size is 59.6Mb
      sub-directories of 1Mb or more:
        libs  59.0Mb
      ```
    - NOTE 3 - **GNU make is needed for handling the Makevars files that rstantools uses to compile the packages Stan models. It’s fairly commonly used for R packages with more complex Makefile needs.  See [this](https://discourse.mc-stan.org/t/using-rstan-in-an-r-package-generates-r-cmd-check-notes/26628) Stan Forums thread.**
    
      ```
      * checking for GNU extensions in Makefiles ... NOTE
      GNU make is a SystemRequirements.
      ```
    - NOTE 4 - **This note is unrelated to the Bernadette package.**
      ```
      * checking HTML version of manual ... NOTE
      Skipping checking HTML validation: no command 'tidy' found
      Skipping checking math rendering: package 'V8' unavailable
      ```
  - Debian Linux, R-devel, GCC ASAN/UBSAN
    - Identical notes to those from the Ubuntu Linux platform.
  - Fedora Linux, R-devel, clang, gfortran
    - Identical notes to those from the Ubuntu Linux platform.
      
## R CMD check results

0 errors | 0 warnings | 0 notes

* This is a new release.

## Reverse dependencies

There are no reverse dependencies for v1.1.1 of the Bernadette package.

Thank you,

Lampros Bouranis
