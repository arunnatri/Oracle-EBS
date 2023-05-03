--
-- XXD_FA_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   XXD_COMMON_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_CONV_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FA_CONV_PKG
    * Author       : BT Technology Team
    * Created      : 07-JUL-2014
    * Program Name : XXD FA Conversion - Extract, Validate and Load Program
    * Description  : This package contains procedures and functions to extract, validate and
    *                load data to interface table for FA Conversion.
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created package body script for FA Conversion
    ****************************************************************************************/
    gc_debug_flag        VARCHAR2 (10);
    gd_sys_date          DATE := SYSDATE;
    gn_conc_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_login_id          NUMBER := fnd_global.login_id;
    gc_fa_module         VARCHAR2 (10) := 'FA';
    gc_program_name      VARCHAR2 (100);
    gn_org_id            NUMBER := xxd_common_utils.get_org_id;

    --Start comment as Deckers Fixed Asset Conversion Program,Deckers Fixed Asset Load Conversion Program,Deckers Fixed Asset Validate Conversion Program not required

    /* PROCEDURE extract_records_prc (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2);

     PROCEDURE create_batch_prc (
        x_retcode      OUT      NUMBER,
        x_errbuff      OUT      VARCHAR2,
        p_batch_size   IN       NUMBER
     );

     PROCEDURE val_load_main_prc (
        x_retcode      OUT      NUMBER,
        x_errbuff      OUT      VARCHAR2,
        p_process      IN       VARCHAR2,
        p_batch_size   IN       NUMBER,
        p_debug        IN       VARCHAR2
     );

     PROCEDURE validate_records_prc (
        x_retcode      OUT      NUMBER,
        x_errbuff      OUT      VARCHAR2,
        p_batch_low    IN       NUMBER,
        p_batch_high   IN       NUMBER,
        p_debug        IN       VARCHAR2
     );

     PROCEDURE interface_load_prc (
        x_retcode      OUT      NUMBER,
        x_errbuff      OUT      VARCHAR2,
        p_batch_low    IN       NUMBER,
        p_batch_high   IN       NUMBER,
        p_debug        IN       VARCHAR2
     );

     PROCEDURE error_log_prc;

     PROCEDURE print_processing_summary (p_mode IN VARCHAR2);*/

    --End comment as Deckers Fixed Asset Conversion Program,Deckers Fixed Asset Load Conversion Program,Deckers Fixed Asset Validate Conversion Program not required

    PROCEDURE update_deprn_flag (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_flag IN VARCHAR2
                                 , p_asset_number IN VARCHAR2);
END xxd_fa_conv_pkg;
/
