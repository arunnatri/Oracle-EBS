--
-- XXDO_COMMON_PKG  (Package) 
--
--  Dependencies: 
--   FND_PROFILE_OPTIONS (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_COMMON_PKG"
AS
    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : spool_query                                            --
    -- PARAMETERS  : pv_spoolfile     - Spool File to be created            --
    --               pv_directory     - Directory name to place file        --
    --               pv_header        - Heading for the file                --
    --               pv_spoolquery    - Query to be processed                --
    --               pv_delimiter     - Delimiter to separate the columns   --
    --               pv_quote        - Quote to be used to put data columns--
    --               pxn_record_count - Number of records processed         --
    -- PURPOSE     : This procedure will be used to spool a query and write --
    --               the query data to the specified file.                  --
    --                                                                      --
    --               Procedure validates that File and Query are not null   --
    --               It also confirms that query is a SELECT query. Then    --
    --               query is parsed and executed. For each record retrieved--
    --               the columns of the query are concatenated together     --
    --               and written to the file using UTL_FILE utility.        --
    --                                             --
    -- Modification History                                          --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE spool_query (pv_spoolfile IN VARCHAR2, pv_directory IN VARCHAR2, pv_header IN VARCHAR2 DEFAULT 'DEFAULT', pv_spoolquery IN VARCHAR2, pv_delimiter IN VARCHAR2 DEFAULT CHR (9), pv_quote IN VARCHAR2 DEFAULT NULL
                           , pxn_record_count OUT NUMBER);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : send_email                                             --
    -- PARAMETERS  : pv_sender        - Sender of the email                 --
    --               pv_recipient     - Recipient of the email. Multiple    --
    --                                  addresses should be comma separated --
    --               pv_ccrecipient   - CC Recipient of the email. Multiple --
    --                                  addresses should be comma separated --
    --               pv_subject       - Subject of the email                --
    --               pv_body          - Body of the email                   --
    --            pv_attachments   - Attachments in the email. Multiple  --
    --                                  attachments should be comma         --
    --                                  separated. Complete unix file path  --
    --                                  name should be provided             --
    --           pn_request_id       - Request Id
    -- PURPOSE     : This procedure will be used to send email with         --
    --               attachments                                            --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE send_email (pv_sender        IN VARCHAR2 DEFAULT NULL,
                          pv_recipient     IN VARCHAR2,
                          pv_ccrecipient   IN VARCHAR2 DEFAULT NULL,
                          pv_subject       IN VARCHAR2,
                          pv_body          IN VARCHAR2 DEFAULT NULL,
                          pv_attachments   IN VARCHAR2 DEFAULT NULL,
                          pn_request_id    IN NUMBER DEFAULT NULL,
                          pv_override_fn   IN VARCHAR2 DEFAULT NULL);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : notify                                                 --
    -- PARAMETERS  : pv_exception_code - Exception Code                     --
    --           pv_program_code   - Program Code
    -- PURPOSE     : This procedure will be used to send notifications      --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer              Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys               1.0          Initial Version         --
    -- 02/25/2013   Pushkal Mishra CG     1.1          Added Application_id parameter
    --------------------------------------------------------------------------
    PROCEDURE notify (xv_errbuf              OUT VARCHAR2,
                      xn_retcode             OUT NUMBER,
                      pv_exception_code   IN     VARCHAR2 DEFAULT NULL,
                      pv_program_code     IN     VARCHAR2 DEFAULT NULL,
                      pn_application_id   IN     NUMBER DEFAULT NULL);

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_converted_uom_qty                                  --
    -- PARAMETERS  : pn_item_id  - Inventory Item id                        --
    --     pv_from_uom - From UOM Code                            --
    --     pv_to_uom   - To Primary UOM Code                      --
    --               pn_from_qty - From Quantity                            --
    --     pn_batch_id - Batch id to set operation key            --
    --      pv_item_code - Item name to pass error message         --
    -- PURPOSE     : This function will be used to return quantity in       --
    --               Primary UOM based on the input quantity and UOM        --
    --                   --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 04/09/2013   Infosys   1.0    Initial Version         --
    ---------------------------------------------------------------------------
    FUNCTION get_converted_uom_qty (pn_item_id IN NUMBER, pv_from_uom IN VARCHAR2, pv_to_uom IN VARCHAR2
                                    , pn_from_qty IN NUMBER, pn_batch_id IN NUMBER, pv_item_code IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : CANCEL_ORDER_LINE                                      --
    -- PARAMETERS  : xn_retcode - Return Code                               --
    --                    0 - Success       --
    --                    1 - Error                                         --
    --               pn_line_id - Line id which is to be cancelled          --
    --               pv_load_nbr - Load Number to set additional attributes --
    --               pn_trip_id - Trip id to set additional attributes      --
    --               pn_delivery_detail_id - Delivery detail id             --
    --               pv_cancel_reason - Reason to cancel the line           --
    --               pn_cancel_qty - Cancelled quantity                     --
    --               pn_ordered_qty - Ordered quantity                      --
    --               pv_event - Event to be performed. It can have 2 values --
    --                          1. LINE                                     --
    --                          2. QTY                                      --
    -- PURPOSE     : This procedure is used to call process order API to    --
    --               cancel order line based on the parameters passed       --
    --            --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 05/21/2013   Infosys   1.0    Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE cancel_order_line (xn_retcode OUT NUMBER, pn_line_id IN NUMBER, pv_load_nbr IN VARCHAR2, pn_trip_id IN NUMBER, pn_delivery_detail_id IN NUMBER, pv_cancel_reason IN VARCHAR2
                                 , pn_cancel_qty IN NUMBER, pn_ordered_qty IN NUMBER, pv_event IN VARCHAR2);

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : GET_MASTER_ORG                                         --
    -- PARAMETERS  : xn_retcode - Return Code                               --
    --
    -- PURPOSE     : This procedure is used to fetch Master org Id          --
    --            --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 06/24/2013   Infosys   1.0    Initial Version         --
    --------------------------------------------------------------------------
    FUNCTION get_master_org
        RETURN NUMBER;

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : GET_OP_UNIT                                            --
    -- PARAMETERS  : pn_organization_id                                     --
    --               pv_organization_code                                   --
    -- PURPOSE     : This procedure is used to fetch Operating Unit         --
    --            --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 06/24/2013   Infosys   1.0    Initial Version         --
    --------------------------------------------------------------------------
    FUNCTION get_op_unit (pn_organization_id     IN NUMBER,
                          pv_organization_code   IN VARCHAR2)
        RETURN VARCHAR2;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : PROCESS_ITEM_UDA                                       --
    -- PARAMETERS  : pn_user_id                                             --
    --               pn_resp_id                                             --
    --               pn_resp_appl_id                                        --
    --               pn_org_id                                              --
    --               pn_item_id                                             --
    --               pn_attr_group_id                                       --
    --               pn_attr_value                                          --
    --               pv_transaction_type                                    --
    --               pv_attr_value                                          --
    --               pv_attr_name                                           --
    --               pv_attr_disp_name                                      --
    --               pv_attr_level                                          --
    --               pd_attr_value                                          --
    --               xv_return_status                                       --
    --               pv_organization_code                                   --
    -- PURPOSE     : This procedure is used to Create/Update/Delete         --
    --               Item User Defined Attributes                           --
    --            --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date         Developer   Version      Description             --
    -- ----------   ---------   --------     ------------    -----------------
    -- 06/24/2013   Infosys      1.0         Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE process_item_uda (pn_user_id            IN     NUMBER,
                                pn_resp_id            IN     NUMBER,
                                pn_resp_appl_id       IN     NUMBER,
                                pn_org_id             IN     NUMBER,
                                pn_item_id            IN     NUMBER,
                                pn_attr_group_id      IN     NUMBER,
                                pn_attr_value         IN     NUMBER,
                                pv_transaction_type   IN     VARCHAR2,
                                pv_attr_value         IN     VARCHAR2,
                                pv_attr_name          IN     VARCHAR2,
                                pv_attr_disp_name     IN     VARCHAR2,
                                pv_attr_level         IN     VARCHAR2,
                                pd_attr_value         IN     DATE,
                                xv_return_status         OUT VARCHAR2);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                                        --
    -- NAME        : spool_email_pgm                                             --
    -- PARAMETERS  : xv_errbuf     -  Return Error message           --
    --               xn_retcode             - Return Error Code                 --
    --               xn_record_count    - Number of records processed --
    --               pn_spool_id            - Spool query Id                      --
    -- PURPOSE     : This procedure will be used to spool a query    --
    --               and write the query data to the specified file.          --
    --                                                                                         --
    -- Modification History                                                             --
    ----------------------------------------------------------------------------
    -- Date      Developer      Version      Description                        --
    -- ----------   -----------     ------------    -------------------------------
    -- 08/30/2013   Infosys      1.0          Initial Version                    --
    -----------------------------------------------------------------------------
    PROCEDURE spool_email_pgm (xv_errbuf        OUT VARCHAR2,
                               xn_retcode       OUT NUMBER,
                               pn_spool_id   IN     NUMBER);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : is_this_prod                                           --
    -- PARAMETERS  : pv_prod_flag                                           --
    --                   Returns Y if current instance is production        --
    --                   otherwise N                                        --
    --               pv_curr_instance - returns instance name               --
    --               pv_prod_instance - returns production instance name    --
    --               instance                                               --
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------
    PROCEDURE is_this_prod (pv_prod_flag OUT VARCHAR2, pv_curr_instance OUT VARCHAR2, pv_prod_instance OUT VARCHAR2);

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_edi_server_url                                     --
    -- PARAMETERS  :                                                        --
    --               Function returns the edi host details depending on     --
    --               instance                                               --
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------

    FUNCTION get_edi_server_url
        RETURN VARCHAR2;

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_edi_server_url                                     --
    -- PARAMETERS  : pv_uri_profile_name                                    --
    --               This is an overload function returns the edi server url--
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------
    FUNCTION get_edi_server_url (
        pv_uri_profile_name   IN apps.fnd_profile_options.profile_option_name%TYPE)
        RETURN VARCHAR2;
END xxdo_common_pkg;
/
