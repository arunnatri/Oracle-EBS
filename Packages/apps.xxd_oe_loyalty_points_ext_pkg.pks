--
-- XXD_OE_LOYALTY_POINTS_EXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OE_LOYALTY_POINTS_EXT_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_OE_LOYALTY_POINTS_EXT_PKG
     REPORT NAME    : Deckers Loyalty Balances Extract Program

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     30-JUL-2021 Showkath           1.0      Created this package using XXD_OE_LOYALTY_POINTS_EXT_PKG
                                             for sending the report output to BlackLine
    *********************************************************************************************/
    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2);

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2 DEFAULT 'XXD_LCX_BAL_BL_INB_DIR', p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , p_num_of_columns IN NUMBER, retcode OUT VARCHAR2, errbuf OUT VARCHAR2);

    PROCEDURE CopyFile_prc (p_in_filename IN VARCHAR2, p_out_filename IN VARCHAR2, p_src_dir VARCHAR2
                            , p_dest_dir VARCHAR2);

    PROCEDURE MAIN_PRC (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_org_id IN NUMBER
                        , pv_type IN VARCHAR2, pv_period_end_date IN VARCHAR2, pv_file_path IN VARCHAR2);
/* PROCEDURE write_ret_recon_file (pv_file_path    IN     VARCHAR2,
                                 pv_file_name    IN     VARCHAR2,
                                 pv_type         IN     VARCHAR2,
                                 x_ret_code         OUT VARCHAR2,
                                 x_ret_message      OUT VARCHAR2);

/* PROCEDURE write_op_file (pv_file_path        IN     VARCHAR2,
                          pv_file_name        IN     VARCHAR2,
                          pv_period_end_date   IN     VARCHAR2,
                          pv_type             IN     VARCHAR2,
                          x_ret_code             OUT VARCHAR2,
                          x_ret_message          OUT VARCHAR2);*/

--PROCEDURE update_valueset_prc (pv_file_path IN VARCHAR2);

/* PROCEDURE update_attributes (x_ret_message          OUT VARCHAR2,
                              pv_period_end_date   IN     VARCHAR2,
                              pv_type             IN     VARCHAR2
                              );*/
END XXD_OE_LOYALTY_POINTS_EXT_PKG;
/
