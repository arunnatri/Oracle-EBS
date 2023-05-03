--
-- XXD_ONT_VAS_CODE_UPDT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_VAS_CODE_UPDT_PKG"
AS
    /*******************************************************************************
   * Program Name : xxd_ont_vas_code_updt_pkg
   * Language     : PL/SQL
   * Description  : This package will be Used to update the VAs Code
   *
   * History      :
   *
   * WHO                 WHAT              Desc                                               WHEN
   * -------------- ------------------------------------------------------------------- ---------------
   *  Laltu               1.1           Updated for CCR0009521                              01-SEP-2021
   *  Laltu               1.2           Updated for CCR0009629                              05-OCT-2021
   *  Ramesh BR     1.3   Updated for CCR0010027        28-JUL-2022
   *  Laltu        1.4   Updated for CCR0010205        19-OCT-2022
   *  Pardeep Rohilla   1.5   Updated for CCR0010299        26-DEC-2022
   * ----------------------------------------------------------------------------------------------------- */
    /******************************************************
   * Procedure:   main
   *
   * Synopsis: This Procedure is for update the vas code.
   * Design:
   *
   * Notes:
   *
   * Modifications:
   *
   ******************************************************/
    TYPE so_hdr_line_id_rec_type IS RECORD
    (
        hdr_line_id    NUMBER,
        vas_code       VARCHAR2 (200)
    );

    TYPE so_hdr_line_id_tbl_type IS TABLE OF so_hdr_line_id_rec_type
        INDEX BY BINARY_INTEGER;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_tran_type VARCHAR2, p_order_num IN NUMBER, p_order_age IN NUMBER, -- Added for CCR0009629
                                                                                                                                                       p_operation_type IN VARCHAR2, P_Hidden_Parameter IN VARCHAR2, p_account_number IN VARCHAR2
                    ,                                  -- Added for CCR0010299
                      p_order_source VARCHAR2          -- Added for CCR0010299
                                             );

    --Start Added as per CCR0010027
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER, p_style IN VARCHAR2, p_color IN VARCHAR2, p_master_class IN VARCHAR2 DEFAULT NULL
                           , --p_sub_class IN VARCHAR2 DEFAULT NULL --  Comment for CCR0010205
                             p_department IN VARCHAR2 DEFAULT NULL --  Added for CCR0010205
                                                                  )
        RETURN VARCHAR2;

    --End Added as per CCR0010027

    PROCEDURE update_header_vas_code (pv_header_id IN NUMBER); -- Added for CCR0010299
END XXD_ONT_VAS_CODE_UPDT_PKG;
/
