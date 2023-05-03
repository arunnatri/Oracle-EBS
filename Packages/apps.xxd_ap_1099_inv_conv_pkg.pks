--
-- XXD_AP_1099_INV_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_1099_INV_CONV_PKG"
AS
    /*******************************************************************************
    * Program Name : XXD_AP_1099_INV_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will load invoices data in to Oracle Payable base tables
    *
    * History      :
    *
    * WHO            WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    *  Swapna N     1.0                                             17-JUN-2014
    *  Krishna H    1.1               ccid and tax code             16-May-2015
    * --------------------------------------------------------------------------- */


    /****************************************************************************************
          * Procedure : Extract`_invoice_proc
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to staging table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * Aug/6/2014   Swapna N        1.00       Created
          ****************************************************************************************/

    PROCEDURE EXTRACT_INVOICE_PROC (p_extract_date   IN VARCHAR2,
                                    p_gl_date        IN VARCHAR2);


    /****************************************************************************************
          * Procedure : INTERFACE_LOAD_PRC
          * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
          * Design    : Procedure loads data to interface table for AP Invoice Conversion
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/
    PROCEDURE INTERFACE_LOAD_PRC (x_retcode         OUT NUMBER,
                                  x_errbuff         OUT VARCHAR2,
                                  p_batch_low    IN     NUMBER,
                                  p_batch_high   IN     NUMBER,
                                  p_debug        IN     VARCHAR2);

    /******************************************************
       * Procedure: XXD_AP_INVOICE_MAIN_PRC
       *
       * Synopsis: This procedure will call we be called by the concurrent program
       * Design:
       *
       * Notes:
       *
       * PARAMETERS:
       *   OUT: (x_retcode  Number
       *   OUT: x_errbuf  Varchar2
       *   IN    : p_process  varchar2
       *   IN    : p_debug  varchar2
       *
       * Return Values:
       * Modifications:
       *
       ******************************************************/

    PROCEDURE XXD_AP_1099_INV_MAIN_PRC (x_retcode            OUT NUMBER,
                                        x_errbuf             OUT VARCHAR2,
                                        p_process         IN     VARCHAR2,
                                        p_debug           IN     VARCHAR2,
                                        p_batch_size      IN     NUMBER,
                                        p_validate_item   IN     VARCHAR2,
                                        p_extract_date    IN     VARCHAR2,
                                        p_gl_date         IN     VARCHAR2);


    /****************************************************************************************
   * Procedure : VALIDATE_RECORDS_PRC
   * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
   * Design    : Procedure validates data for AP Invoice conversion
   * Notes     :
   * Return Values: None
   * Modification :
   * Date          Developer     Version    Description
   *--------------------------------------------------------------------------------------
   * 07-JUL-2014   Swapna N        1.00       Created
   ****************************************************************************************/

    PROCEDURE VALIDATE_RECORDS_PRC (x_retcode         OUT NUMBER,
                                    x_errbuff         OUT VARCHAR2,
                                    p_batch_low    IN     NUMBER,
                                    p_batch_high   IN     NUMBER,
                                    p_debug        IN     VARCHAR2);

    /****************************************************************************************
     * Procedure : CREATE_BATCH_PRC
     * Synopsis  : This Procedure shall create batch Processes
     * Design    : Program input p_batch_size is considered to divide records and batch number is assigned
     * Notes     :
     * Return Values: None
     * Modification :
     * Date          Developer     Version    Description
     *--------------------------------------------------------------------------------------
     * 07-JUL-2014   Swapna N        1.00       Created
     ****************************************************************************************/


    PROCEDURE CREATE_BATCH_PRC (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_batch_size IN NUMBER
                                , p_debug IN VARCHAR2);

    /****************************************************************************************
    * Procedure : GET_NEW_ORG_ID
    * Synopsis  : This Procedure shall provide the new org_id for given 12.0 operating_unit name
    * Design    : Program input old_operating_unit_name is passed
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   Swapna N        1.00       Created
    ****************************************************************************************/

    PROCEDURE GET_NEW_ORG_ID (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_NEW_ORG_ID OUT NUMBER
                              , x_new_org_name OUT VARCHAR2);

    PROCEDURE IMPORT_INVOICE_FROM_INTERFACE (p_org_id IN NUMBER, p_debug_flag IN VARCHAR2, p_gl_date IN VARCHAR2);

    /****************************************************************************************
       * Procedure : VALIDATE_INVOICE
       * Synopsis  : This Procedure will validate invoices created from open interface import
       * Design    :
       * Notes     :
       * Return Values: None
       * Modification :
       * Date          Developer     Version    Description
       *--------------------------------------------------------------------------------------
       * 07-JUL-2014   Swapna N        1.00       Created
       ****************************************************************************************/

    PROCEDURE VALIDATE_INVOICE (p_debug_flag IN VARCHAR2);

    /****************************************************************************************
          * Procedure : PRINT_LOG_PRC
          * Synopsis  : This Procedure shall write to the concurrent program log file
          * Design    : Program input debug flag is 'Y' then the procedure shall write the message
          *             input to concurrent program log file
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 07-JUL-2014   Swapna N        1.00       Created
          ****************************************************************************************/

    PROCEDURE PRINT_LOG_PRC (p_debug_flag IN VARCHAR2, p_message IN VARCHAR2);

    PROCEDURE Update_CM (x_retcode         OUT NUMBER,
                         x_errbuff         OUT VARCHAR2,
                         p_debug_flag   IN     VARCHAR2);
END XXD_AP_1099_INV_CONV_PKG;
/
