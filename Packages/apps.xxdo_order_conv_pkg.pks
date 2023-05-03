--
-- XXDO_ORDER_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ORDER_CONV_PKG"
IS
    PROCEDURE process_order (out_chr_errbuf OUT VARCHAR2, out_chr_retcode OUT NUMBER, in_num_worker_number IN NUMBER
                             , in_num_parent_request_id IN NUMBER);

    PROCEDURE main (out_chr_errbuf OUT VARCHAR2, out_chr_retcode OUT NUMBER, p_source_organization IN VARCHAR2, p_target_organization IN VARCHAR2, p_so_number IN VARCHAR2, p_workers IN NUMBER, p_brand IN VARCHAR2, p_gender IN VARCHAR2, p_prod_group IN VARCHAR2
                    , p_mode IN VARCHAR2, p_request_id IN NUMBER);
END xxdo_order_conv_pkg;
/
