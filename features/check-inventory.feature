Feature:
In order to know if may backup is corrupt I would like to be able to
check my files against my inventory.

    Scenario: backup matches with inventory.  
    Given that I have access to basic-test-data-directory
    and that I have made an inventory file for that directory
    when I run inventory-check on the inventory file
    then the inventory-check command should succeed

    Scenario: a file doesn't match inventory.  
    Given that I have access to basic-test-data-directory
    and that I have made an inventory file for that directory with one file corrupted
    when I run inventory-check on the inventory file
    then the inventory-check command should fail
    and print out the corrupted filename

    Scenario: a file is missing
    Given that I have access to basic-test-data-directory
    and that I have made an inventory file for that directory with one additional file
    when I run inventory-check on the inventory file
    then the inventory-check command should fail
    and print out the missing filename

