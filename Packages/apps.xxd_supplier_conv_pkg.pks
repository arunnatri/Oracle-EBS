--
-- XXD_SUPPLIER_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SUPPLIER_CONV_PKG"
    AUTHID CURRENT_USER
AS
    /*****************************************************************************/
    /*                                                                           */
    /* $Header: XX_SUPPLIER_CONV_PKG.pks 1.0 2013/01/10   $             */
    /*                                                                           */
    /* PROCEDURE NAME:  XX_SUPPLIER_CONV_PKG                                    */
    /*                                                                           */
    /* PROGRAM NAME:  XXD AP Supplier Validate and Load program                   */
    /*                <List Multiple Concurrent Program if needed>               */
    /*                                                                           */
    /* DEPENDENCIES: -NA-                                                        */
    /*                                                                           */
    /*                                                                           */
    /* REFERENCED BY: XXD AP Supplier Business CLassification Creation Program*/
    /*                                                                           */
    /*                                                                           */
    /* DESCRIPTION:  Import the AP Supplier/Sites/Contacts/Banks/Branches
                       /Accounts/Business Classification  Data in R12            */
    /*                                                                           */
    /*                                                                           */
    /* HISTORY:                                                                  */
    /*---------------------------------------------------------------------------*/
    /* Verson Num       Developer          Date           Description            */
    /*                                                                           */
    /*---------------------------------------------------------------------------*/
    /* 1.00                       1-Oct-2013    R12 Upgrade            */
    /*                                                                           */
    /*---------------------------------------------------------------------------*/
    /*                                                                           */
    /*****************************************************************************/
    PROCEDURE extract_r1206_supplier_info (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_debug IN VARCHAR2);

    PROCEDURE validate_supplier_info (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_process_mode IN VARCHAR2
                                      , p_debug IN VARCHAR2);

    PROCEDURE supp_bank_acct (x_errbuf       OUT VARCHAR2,
                              x_retcode      OUT NUMBER,
                              p_debug     IN     VARCHAR2);

    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_mode IN VARCHAR2
                    , p_debug IN VARCHAR2);

    PROCEDURE GET_ORG_ID (p_org_name   IN            VARCHAR2,
                          x_org_id        OUT NOCOPY NUMBER,
                          x_org_name      OUT NOCOPY VARCHAR2);

    PROCEDURE print_processing_summary (p_debug IN VARCHAR2, p_mode IN VARCHAR2, x_ret_code OUT NUMBER);
END xxd_supplier_conv_pkg;
/
