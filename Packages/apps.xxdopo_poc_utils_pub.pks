--
-- XXDOPO_POC_UTILS_PUB  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOPO_POC_UTILS_PUB"
AS
    /*************************************************************
          Date        Version                   Notes
          10-12-16    1.0                       Initial deployment
          6-28-19     1.1    Gjensen            CCR0007979 - Updated parameters of get_po_type function
          5-28-20     1.2    GJensen            CCR0008134 - POC upgrade
          03-03-21    1.4    Satyanarayana.kotha CCR0009182 - POC Changes
    /*************************************************************/


    ------------------------------------------------------------------------------------------
    --Global Variables Declaration
    ------------------------------------------------------------------------------------------
    gn_resp_id                              NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id                         NUMBER := apps.fnd_global.resp_appl_id;

    gv_mo_profile_option_name      CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ;
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ;
    gv_responsibility_name         CONSTANT VARCHAR2 (240)
                                                := 'Deckers Purchasing User' ;
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management User' ;

    --Field lookup values
    gLookupTrueFalse               CONSTANT NUMBER := 1013975;
    gLookupYN                      CONSTANT NUMBER := 1003492;
    gLookupShipMethod              CONSTANT NUMBER := 1015991;
    gLookupFreightPayParty         CONSTANT NUMBER := 1016006;

    G_PO_TYPE_DIRECT               CONSTANT NUMBER := 1;
    G_PO_TYPE_DS                   CONSTANT NUMBER := 2;
    G_PO_TYPE_INTERCO              CONSTANT NUMBER := 3;
    G_PO_TYPE_XDOCK                CONSTANT NUMBER := 4;
    G_PO_TYPE_JPTQ                 CONSTANT NUMBER := 5;          --CCR0008134
    G_PO_TYPE_DSHIP                CONSTANT NUMBER := 6;          --CCR0008134
    G_PO_TYPE_UNDEF                CONSTANT NUMBER := -1;
    G_PO_TYPE_ERR                  CONSTANT NUMBER := 0;

    gBatchO2F_User                 CONSTANT VARCHAR2 (20) := 'BATCH.O2F';
    gBatchP2P_User                 CONSTANT VARCHAR2 (20) := 'BATCH.P2P';

    --BATCH.P2P
    gDefREQPreparerID              CONSTANT NUMBER := 2635; --CCR0008134 Updated to BATCH.P2P
    gDefREQUserID                  CONSTANT NUMBER := 1876; --CCR0008134 Updated to BATCH.P2P

    gv_source_code                          VARCHAR2 (20)
                                                := 'PO_Cancel_Rebook';
    gn_cancel_reason_code                   VARCHAR2 (20) := '2'; --Related PO changes
    gn_max_retry                   CONSTANT NUMBER := 3;

    /********************************************************
    SOA Event types
    ********************************************************/

    gn_event_supplier_site         CONSTANT VARCHAR2 (50)
        := 'OrderAssignmentChangeActivatedEvent' ;                --CCR0008134
    gn_event_po_change             CONSTANT VARCHAR2 (50)
        := 'OrderCollaborationAmendmentEvent' ;                   --CCR0008134


    /********************************************************
    Public Utility Functions
    **********************************************************/

    /*
    Approve_po
    runs the std po approval function on the passed in PO using the defined user ID

    pv_po_number - PO number to approve
    pm_user_id -- User to log into purchasing
    pv_error_stat --Return status
    pv_error_msg - Error message

    */
    PROCEDURE approve_po (pv_po_number IN VARCHAR2, pn_user_id IN NUMBER, pv_error_stat OUT VARCHAR2
                          , pv_error_msg OUT VARCHAR2);

    /*
    run_workflow_bkg
    Runs the Oracle Workflow Background Process

    p_user_id -- User to log into for the process
    p_status --Return status
    p_msg - Error message
    p_request_id - request ID of process run

    */
    PROCEDURE run_workflow_bkg (p_user_id IN NUMBER, p_status OUT VARCHAR, p_msg OUT VARCHAR2
                                , p_request_id OUT NUMBER);

    /*
    check_so_hold_status
    Checks holds status of a sales order. Option to release holds

    pn_so_header_id - Header ID of SO to check
    pb_release_hold - attempt to release any holds
    p_user_id -- User to log into for the process
    pv_error_stat --Return status
    p_msg - Error message
    pv_error_msg - request ID of process run

    Returns number of holds after check/release attempt

    */
    FUNCTION check_so_hold_status (pn_so_header_id   IN     NUMBER,
                                   pb_release_hold   IN     BOOLEAN := FALSE,
                                   pn_user_id        IN     NUMBER,
                                   pv_error_stat        OUT VARCHAR2,
                                   pv_error_msg         OUT VARCHAR2)
        RETURN NUMBER;


    /*
    get_po_line_source_type

    pv_po_number - Po number to check

    Returns PO type from the G_PO_TYPE set of constants
    */
    FUNCTION get_po_type (pv_po_number IN VARCHAR2)               --CCR0007979
        RETURN NUMBER;

    /*
    run_std_po_import
    Run standard PO import to create a PO from posted PO interface records

    pn_batch_id - Batch ID assigned to PO interface header
    pn_org_id - Org ID to use
    pn_user_id - User ID for purchasing
    pn_request_id - Request ID of Import request,
    pv_error_sta t- Error status
    pv_error_msg - error message
     */
    PROCEDURE close_po_line (pv_po_number    IN     VARCHAR2,
                             pn_line_num     IN     NUMBER,
                             --pn_shipment_num   IN     NUMBER,
                             pn_user_id      IN     NUMBER,
                             pv_error_stat      OUT VARCHAR2,
                             pv_error_msg       OUT VARCHAR2);

    --Begin CCR0008143
    /*
       PROCEDURE run_std_po_import (pn_batch_id     IN     NUMBER,
                                    pn_org_id       IN     NUMBER,
                                    pn_user_id      IN     NUMBER,
                                    pn_request_id      OUT NUMBER,
                                    pv_error_stat      OUT VARCHAR2,
                                    pv_error_msg       OUT VARCHAR2);
                                    */
    --End CCR0008143

    PROCEDURE set_om_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
                              , pv_error_msg OUT VARCHAR2);

    PROCEDURE validate_stg_record (pn_gtn_po_collab_stg_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2);

    /*
   post_gtn_poc_to_stage
   Procedure to post records to the staging table

   Parameters described below
    */
    PROCEDURE post_gtn_poc_to_stage (pn_batch_id IN OUT NUMBER, --OPT : If not provided, it will be auto generated and the batch number value will be returned.
                                                                pv_po_number IN VARCHAR2:= NULL, --REQ
                                                                                                 pv_item_key IN VARCHAR2, --REQ (format x.x.x)
                                                                                                                          pv_split_flag IN VARCHAR2:= 'true', --OPT (true/false)LOV TrueFalseValueSet- 1013975
                                                                                                                                                              pv_shipmethod IN VARCHAR2:= NULL, --OPT (Air, Ocean) LOV XXDO_SHIP_METHOD - 1015991
                                                                                                                                                                                                pn_quantity IN NUMBER:= NULL, --REQ (value > 0)
                                                                                                                                                                                                                              pv_cexfactory_date IN VARCHAR2:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                     pn_unit_price IN NUMBER:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                                                     pv_new_promised_date IN VARCHAR2:= NULL, --OPT -DEF value from PLLA
                                                                                                                                                                                                                                                                                                                                              pv_freight_pay_party IN VARCHAR2:= NULL, --OPT (Deckers, Factory, Vendor) LOV XXDO_FREIGHT_PAY_PARTY_LOV - 1016006
                                                                                                                                                                                                                                                                                                                                                                                       pv_original_line_flag IN VARCHAR2:= 'false', --OPT (true/false) LOV TrueFalseValueSet - 1013975
                                                                                                                                                                                                                                                                                                                                                                                                                                    pv_supplier_site_code IN VARCHAR2:= NULL, --OPT For supplier site chang e       --CCR0008134
                                                                                                                                                                                                                                                                                                                                                                                                                                                                              pv_delay_reason IN VARCHAR2:= NULL, --OPT Delay reason                    --CCR0008134
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  pv_comments1 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   pv_comments2 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    pv_comments3 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     pv_comments4 IN VARCHAR2:= NULL, --OPT - Optional comments/notes field
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      pv_error_stat OUT VARCHAR2
                                     , pv_error_msg OUT VARCHAR2);

    /*
    run_poc_batch
    Runs the cancel/rebook process against a batch of records in the staging table. This is the function that can be set for a concurrent request.
    */
    PROCEDURE run_poc_batch (pn_batch_id     IN     NUMBER,
                             pv_reprocess    IN     VARCHAR2 := 'No',
                             pv_error_stat      OUT VARCHAR2,
                             pv_err_msg         OUT VARCHAR2,
                             pn_request_id   IN     NUMBER);     -- CCR0006035


    --Updated for CCR0008134
    PROCEDURE run_proc_all (pv_error_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_reprocess IN VARCHAR2:= 'No'
                            , pn_batch_id IN NUMBER:= NULL);

    -- Start CCR0006517
    PROCEDURE check_program_status (pv_conc_short_name IN VARCHAR2, pv_hold_flag IN VARCHAR2, pv_request_id IN OUT NUMBER
                                    , pv_argument1 IN VARCHAR2);
-- End CCR0006517


END xxdopo_poc_utils_pub;
/


GRANT EXECUTE ON APPS.XXDOPO_POC_UTILS_PUB TO SOA_INT
/
