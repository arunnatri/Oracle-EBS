--
-- XXD_ITEM_CONV_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ITEM_CONV_UPDATE_PKG"
AS
    /****************************************************************************************/
    /* PACKAGE NAME:  XXD_ITEM_CONV_PKG                                                                  */
    /*                                                                                                           */
    /* PROGRAM NAME:  XXD INV Item Conversion - Worker Load Program,                              */
    /*         XXD INV Item Conversion - Worker Validate Program,                                 */
    /*        XXD INV Item Conversion - Extract Program,                                               */
    /*        XXD INV Item Conversion - Validate and Load Program                                  */
    /*                                                                                                            */
    /* DEPENDENCIES:  XXD_COMMON_UTILS                                                                      */
    /*                                                                                                           */
    /* REFERENCED BY: N/A                                                                                     */
    /*                                                                                                             */
    /* DESCRIPTION:   Item Conversion for R12 Data Migration                                        */
    /*                                                                                                           */
    /* HISTORY:                                                                                                 */
    /*--------------------------------------------------------------------------------------*/
    /* No     Developer       Date      Description                                                      */
    /*                                                                                                           */
    /*--------------------------------------------------------------------------------------*/
    /* 1.00     BT technology team   13-Jun-2014  Package Specification script for                             */
    /*                          Item Conversion.                                                            */
    /*                                                                                                              */
    /****************************************************************************************/

    PROCEDURE extract_val_load_main (
        x_errbuf                 OUT NOCOPY VARCHAR2,
        x_retcode                OUT NOCOPY NUMBER,
        p_organization_code   IN            VARCHAR2,
        p_process_level       IN            VARCHAR2,
        p_batch_size          IN            NUMBER,
        p_debug_flag          IN            VARCHAR2 DEFAULT 'N',
        p_brand               IN            VARCHAR2,
        pd_last_update_date   IN            VARCHAR2);

    --Start of new prc added by BT Technology Team on 01-Jun-2015
    /*
    PROCEDURE identify_master_attr          (pv_column_name     IN VARCHAR2,  --Column name in mtl_item_attributes
                                             pv_actual_column   IN VARCHAR2,  --column name in staging table
                                             pv_column_value     IN VARCHAR2,  --1206 Master attr value
                                             pn_request_id      IN NUMBER,
               p_item_id   IN NUMBER);

     PROCEDURE identify_child_attr          (pv_column_name    IN VARCHAR2,  --Column name in mtl_item_attributes
                                             pv_actual_column    IN VARCHAR2,   --column name in staging table
                                             pv_column_value     IN VARCHAR2,  --1206 child attr value
                                             pn_request_id       IN NUMBER,
               p_item_id           IN NUMBER,    --added 05-Oct-2015
               p_org_code           IN VARCHAR2);   --added 05-Oct-2015
    */
    --End of new prc added by BT Technology Team on 01-Jun-2015

    PROCEDURE submit_batch_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_organization_code IN VARCHAR2, p_batch_low_limit IN NUMBER, p_batch_high_limit IN NUMBER, p_brand IN VARCHAR2
                                , p_debug_flag IN VARCHAR2);

    PROCEDURE interface_load_prc (
        x_errbuf                 OUT NOCOPY VARCHAR2,
        x_retcode                OUT NOCOPY NUMBER,
        p_organization_code   IN            VARCHAR2,
        p_batch_low_limit     IN            NUMBER,
        p_batch_high_limit    IN            NUMBER);

    PROCEDURE create_batch_prc (p_organization_code IN VARCHAR2, p_batch_size IN NUMBER, x_err_msg OUT VARCHAR2
                                , x_err_code OUT NUMBER);

    PROCEDURE update_results_prc (p_organization_code   IN     VARCHAR2,
                                  p_batch_low_limit     IN     NUMBER,
                                  p_batch_high_limit    IN     NUMBER,
                                  x_err_msg                OUT VARCHAR2,
                                  x_err_code               OUT NUMBER);

    PROCEDURE validate_records_prc (p_organization_code   IN     VARCHAR2,
                                    p_batch_no            IN     NUMBER,
                                    p_brand               IN     VARCHAR2,
                                    x_err_msg                OUT VARCHAR2,
                                    x_err_code               OUT NUMBER);

    --Procedure update_internal_org_flag (p_org_code IN Varchar2);

    PROCEDURE submit_item_import (x_errbuf       OUT NOCOPY VARCHAR2,
                                  x_retcode      OUT NOCOPY NUMBER);

    PROCEDURE print_log (p_message VARCHAR2);

    PROCEDURE PROCESS_ITEM_ORG_ASSIGNMENT (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_debug IN VARCHAR2);
END XXD_ITEM_CONV_UPDATE_PKG;
/
