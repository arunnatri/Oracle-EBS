--
-- XXDO_ONHAND_ISSUE_OUT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_ONHAND_ISSUE_OUT
AS
    -- =========================================================================================
    -- Description:
    -- This package generates miscellaneous issue transactions to reset existing inventory on-hand to zero.
    -- When open PO Receipts and Order Shipments are converted they will create on-hand in the system.
    -- But this on-hand balance should not contribute to the overall on-hand as the actual on-hand balance
    -- as of cutover date will be converted using on-hand conversion program.
    -- This package will be required just before running the actual onhand conversion programs to issue out all existing onhand
    --===========================================================================================

    -- Pseudo Logic
    -- Query and sum up inventory onhand qty by inventory org, subinv, locator and item
    -- Insert into MTL_TRANSACTIONS_INTERFACE
    -- Invoke 'Process transactions interface' concurrent program based on parameter value

    /******************************************************************************
     1.Components:  main_proc
       Purpose: Depending upon parameters this will run group by query to get onhand as of run date
       and insert into interface table. If param pi_submit_conc_prog = 'Y' then it will submit the standard
       program.


       Execution Method: From custom concurrent program

       Note:

     2.Components:  submit_apps_request
       Purpose: This will submit the apps request 'Process Transaction Processor'


       Execution Method:

       Note:

     3.Components:  reinstate_onhand
       Purpose: Proc to create misc receipts based on entries from backup table. To be
       used only on emergency


       Execution Method: Standalone call

       Note:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        4/21/2015             1. Created this package.
    ******************************************************************************/
    -- Define global variables
    g_process_flag       NUMBER := 1;
    g_transaction_mode   NUMBER := 3;                                     --2;
    g_lock_flag          NUMBER := 2;

    PROCEDURE main_proc (
        errbuf                           OUT VARCHAR2,
        retcod                           OUT VARCHAR2,
        pi_transaction_type           IN     VARCHAR2 DEFAULT 'Miscellaneous issue',
        pi_inventory_org_code         IN     VARCHAR2 DEFAULT NULL,
        pi_subinv_code                IN     VARCHAR2 DEFAULT NULL,
        pi_inventory_item_id          IN     NUMBER DEFAULT NULL,
        pi_source_code                IN     VARCHAR2,
        pi_distribution_natural_acc   IN     VARCHAR2);

    PROCEDURE submit_apps_request (pi_inv_org_id IN NUMBER);

    PROCEDURE print_message (ip_text IN VARCHAR2);

    FUNCTION get_account (pi_distribution_natural_acc   IN VARCHAR2,
                          pi_organization_id            IN NUMBER)
        RETURN NUMBER;

    FUNCTION is_backup_ready (pi_inventory_org_code IN VARCHAR2 DEFAULT NULL, pi_subinv_code IN VARCHAR2 DEFAULT NULL, pi_inventory_item_id IN NUMBER DEFAULT NULL)
        RETURN BOOLEAN;

    PROCEDURE reinstate_onhand (
        pi_transaction_type     IN VARCHAR2 DEFAULT 'Miscellaneous receipt',
        pi_inventory_org_code   IN VARCHAR2,
        pi_subinv_code          IN VARCHAR2 DEFAULT NULL,
        pi_inventory_item_id    IN NUMBER DEFAULT NULL);
END xxdo_onhand_issue_out;
/
