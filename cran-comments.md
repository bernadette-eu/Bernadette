# Version 1.1.1

## Test environments

* Local:
  - Windows 10, R 4.2.2 (x86_64-w64-mingw32/x64 (64-bit))
* R-hub builder (https://builder.r-hub.io)
  - Windows Server 2022 R-devel, 64 bit
    - NOTE 1 - The Bernadette package uses the rstan and Rcpp packages to compile models.
    The libs/ directory is where the compiled model object is stored. See [this](https://discourse.mc-stan.org/t/using-rstan-in-an-r-package-generates-r-cmd-check-notes/26628) Stan Forums thread.
      ```
      * checking installed package size ... NOTE
      installed size is  9.3Mb
      sub-directories of 1Mb or more:
        data   6.7Mb
        libs   2.3Mb
      ```
    - NOTE 2 - This note is unrelated to my package:
    
      ```
      * checking HTML version of manual ... NOTE
      Skipping checking math rendering: package 'V8' unavailable
      ```
    - NOTE 3 -  
      ```
      * checking for non-standard things in the check directory ... NOTE
      Found the following files/directories:
      ''NULL''
      ```
    - NOTE 4 - Following [R-hub issue #503](https://github.com/r-hub/rhub/issues/503), this could be due to a bug/crash in MiKTeX and can likely be ignored.
    
      ```
      * checking for detritus in the temp directory ... NOTE
      Found the following files/directories:
      'lastMiKTeXException'
      ```
  - Fedora Linux, R-devel, clang, gfortran
    - NOTE 1 - The Bernadette package uses the rstan and Rcpp packages to compile models.
    The libs/ directory is where the compiled model object is stored. See [this](https://discourse.mc-stan.org/t/using-rstan-in-an-r-package-generates-r-cmd-check-notes/26628) Stan Forums thread.
      ```
      * checking installed package size ... NOTE
      installed size is 36.9Mb
      sub-directories of 1Mb or more:
        data   6.7Mb
        libs  29.7Mb
      ```
    - NOTE 2 - GNU make is needed for handling the Makevars files that rstantools uses to compile the packages Stan models. It’s fairly commonly used for R packages with more complex Makefile needs.  See [this](https://discourse.mc-stan.org/t/using-rstan-in-an-r-package-generates-r-cmd-check-notes/26628) Stan Forums thread.
    
      ```
      * checking for GNU extensions in Makefiles ... NOTE
      GNU make is a SystemRequirements.
      ```
    - NOTE 3 - This note is unrelated to my package:
      ```
      * checking HTML version of manual ... NOTE
      Skipping checking HTML validation: no command 'tidy' found
      Skipping checking math rendering: package 'V8' unavailable
      ```
      
## R CMD check results

0 errors | 0 warnings | 1 note

* NOTE 1 - The Bernadette package uses the rstan and Rcpp packages to compile models. The libs/ directory is where the compiled model object is stored. See [this](https://discourse.mc-stan.org/t/using-rstan-in-an-r-package-generates-r-cmd-check-notes/26628) Stan Forums thread.
  ```
  * checking installed package size ... NOTE
  installed size is  9.3Mb
   sub-directories of 1Mb or more:
     data   6.7Mb
     libs   2.3Mb
  ```
* This is a new release.

Thanks!

Lampros Bouranis
