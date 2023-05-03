--
-- XXDO_ONT_RMS_SO_CONFIRM_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_RMS_SO_CONFIRM_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_ONT_ORDER_MODIFY_PKG
    * Design       : This package will be used for EBS RMS Inegration..
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-Mar-2020  1.0        Gaurav Joshi     Initial Version
 -- 01-Jan-2022  2.1        Shivanshu Talwar        Modified for CCR0009751 - Fix for sending correct Cancellation Message - Split Line Scenario
    ******************************************************************************************/
    PROCEDURE generate_ds_confirmation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2);

    PROCEDURE generate_ni_confirmation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2
                                        , p_num_days IN NUMBER);

    PROCEDURE split_and_schedule (errbuf              OUT VARCHAR2,
                                  retcode             OUT VARCHAR2,
                                  p_enable_debug   IN     VARCHAR2);

    PROCEDURE cancel_unscheduled_lines (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2);

    PROCEDURE cancel_unsched_lines_cuttoff (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2);

    PROCEDURE release_hold (errbuf              OUT VARCHAR2,
                            retcode             OUT VARCHAR2,
                            p_enable_debug   IN     VARCHAR2);

    PROCEDURE insert_prc (p_errfbuf              OUT VARCHAR2,
                          p_retcode              OUT VARCHAR2,
                          p_dc_dest_id        IN     NUMBER,
                          p_distro_no         IN     VARCHAR2,
                          p_distro_doc_type   IN     VARCHAR2,
                          p_cust_ord_no       IN     VARCHAR2,
                          p_dest_id           IN     NUMBER,
                          p_item_id           IN     NUMBER,
                          p_order_line_nbr    IN     NUMBER,
                          p_unit_qty          IN     NUMBER,
                          p_status            IN     VARCHAR2,
                          p_enable_debug      IN     VARCHAR2);
END xxdo_ont_rms_so_confirm_pkg;
/
