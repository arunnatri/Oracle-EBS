--
-- XXDO_ATP_CALCULATION_EBS  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_TABLE_OF_VARCHAR2_4000 (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ATP_CALCULATION_EBS"
AS
    g_ret_success          VARCHAR (1) := fnd_api.g_ret_sts_success;
    g_ret_warn             VARCHAR (1) := 'W';
    g_ret_error            VARCHAR (1) := fnd_api.g_ret_sts_error;
    g_ret_unexp            VARCHAR (1) := fnd_api.g_ret_sts_unexp_error;


    g_status_new           VARCHAR (1) := 'N';
    g_status_submitted     VARCHAR (1) := 'S';
    g_status_processing    VARCHAR (1) := 'P';
    g_status_complete      VARCHAR (1) := 'C';
    g_status_error         VARCHAR (1) := 'E';
    g_status_transmitted   VARCHAR (1) := 'X';
    g_status_aborted       VARCHAR (1) := 'A';

    FUNCTION single_atp (p_source_org_id IN NUMBER, p_inventory_item_id IN NUMBER, p_req_ship_Date IN DATE
                         , p_demand_class IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION single_atr (p_source_org_id       IN NUMBER,
                         p_inventory_item_id   IN NUMBER)
        RETURN NUMBER;

    PROCEDURE validate_atp (p_workers IN NUMBER:= 6);

    PROCEDURE validation_worker;

    PROCEDURE refresh_atp (x_ret_stat        OUT VARCHAR2,
                           x_msg             OUT VARCHAR2,
                           p_force_full   IN     VARCHAR2 := 'N');

    FUNCTION tab_to_string (p_varchar2_tab   IN fnd_table_of_varchar2_4000,
                            p_delimiter      IN VARCHAR2 DEFAULT ',')
        RETURN CLOB;

    PROCEDURE msg (p_msg VARCHAR2, p_level NUMBER:= 10000);

    PROCEDURE refresh_atp_conc (errorbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_force_full IN VARCHAR2);
END xxdo_atp_calculation_ebs;
/
