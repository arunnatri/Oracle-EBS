--
-- XXD_ONT_EDI_VALIDATION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_EDI_VALIDATION_PKG"
AS
    /********************************************************************************************
     * Package         : XXD_ONT_EDI_VALIDATION_PKG
     * Description     : This package is used for EDI Prevalidation
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------------
     * Date          Version#    Name                   Description
     *-------------------------------------------------------------------------------------------
     * 08-JUL-2020   1.0         Aravind Kannuri        Initial Version
     *******************************************************************************************/

    --Main Procedure to call in program
    PROCEDURE main_control (p_errbuf              OUT VARCHAR2,
                            p_retcode             OUT VARCHAR2,
                            p_operating_unit   IN     NUMBER,
                            p_osid             IN     NUMBER,
                            p_cust_po_num      IN     VARCHAR2,
                            p_reprocess_flag   IN     VARCHAR2);
END xxd_ont_edi_validation_pkg;
/
