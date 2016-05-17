#Wrangler Testing With Mocha
Wrangler test driver works by creating a child Pico, removing the production wrangler and installing the development version to be evaluated. 

##Running
Make sure you have node.js installed.  Install mocha if you havent already (npm install -g mocha).  Clone repo, navagate to wrangler/test directory and type mocha.

###Global Varibles & Dependancys
At the top of test.js you will find dependancys and global varibles used for testing.
Use these varibles to calibrate the test driver to your needs.
####Varibles
-**_eci**, the eci of the parent or main pico acount used for testing.

-**wrangler_dev**, the ruleset ID of the devlopment ruleset of wrangler, the wrangler to be tested. 

-**wrangler_prod**, the ruleset ID of the production ruleset of wrangler, the current wrangler.

-**bootstrap_rid**, the ruleset ID of the BootStrapping ruleset.

-**testing_rid1**, ruleset ID of a uncomman ruleset for testing ruleset management. 

-**testing_rid2**, ruleset ID of a uncomman ruleset for testing ruleset management. 

####Dependancys
 -**superTest**, mostly used for http get/post commands
 
 -**chai**, used for asserts 
 
 -**underscore**, functions for manipulating results.
###Tests
####Initailize Testing environment 
-Initailize Testing environment checks that the current version of wrangler has the ability to create a valid pico for testing. Initailize Testing environment then creates a child pico, installs testing wrangler ruleset, uninstalls production wrangler ruleset and validates results with a check. This is tightly coupled with the production version and will need to be updated with every new version. This will fail if the development wrangler does not list installed rulesets correctly.

#####children(_eci) 
-lists current children.
#####install/uninstall ruleset ()
-stores list of current rulesets
-installs ruleset
-compares updated list of rules with previous to insure only desired ruleset was installed. 
-uninstalls ruleset
-compares updated list of rules with first list to insure uninstall success
##### createChild Pico for testing 
-stores list of current children
-creates a child pico
-compares updated list of picos to confirm successful creation, stores new pico eci for testing
-install wrangler.dev() ruleset in child
-uninstall wrangler.prod() & bootstrapping.prod()
-compares updated list of installed rulesets with wrangler.dev, fails if rulesets() is not working or if uninstall failed'
####Main Tests 
