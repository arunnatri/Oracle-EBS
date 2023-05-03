--
-- XXDO_PO_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_EXTRACT_PKG"
AS
    PROCEDURE extract_po_stage_data (p_in_num_organization   IN     NUMBER,
                                     p_in_var_ponumber       IN     VARCHAR2,
                                     p_last_run_date         IN     DATE,
                                     p_in_var_source         IN     VARCHAR2,
                                     p_in_var_dest           IN     VARCHAR2,
                                     p_in_var_purge_days     IN     VARCHAR2,
                                     p_out_var_retcode          OUT VARCHAR2,
                                     p_out_var_errbuf           OUT VARCHAR2);

    PROCEDURE main_extract (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT VARCHAR2, p_organization IN NUMBER, p_po_number IN VARCHAR2, p_debug_level IN VARCHAR2, p_source IN VARCHAR2
                            , p_dest IN VARCHAR2, p_purge_days IN NUMBER);
END xxdo_po_extract_pkg;
/
