--
-- XXDOINV_INTRANSIT_REPORT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_INTRANSIT_REPORT"
AS
    /******************************************************************************************
    * Package          :xxdoinv_intransit_report
    * Author           : BT Technology Team
    * Program Name     : In-Transit Inventory Report - Deckers
    *
    * Modification  :
    *----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *----------------------------------------------------------------------------------------------
    *   22-APRIL-2015 BT Technology Team      V1.1     Package being used for create journals in the GL.
    *   10-JUN-2015    BT Technology Team     V1.2     Fixed the HPQC Defect#2321
    *   03-Dec-2015    BT Technology Team     V1.3     Fixed the HPQC Defect#672
    *   25-June-2019   Greg Jensen            v1.4     CCR0007979 Macau Project
    *   04-May-2021    Tejaswi                V1.5     Changes as per CCR0008870
    *   08-Sep-2021    Balavenu               V1.6     Changes as per CCR0009519
    *   30-Jan-2022    Showkath Ali           V1.7     Changes as per CCR0009826 -- Marubeni changes
    ************************************************************************************************/
    FUNCTION get_duty_cost (p_organization_id       IN NUMBER,
                            p_inventory_item_id     IN NUMBER,
                            p_po_header_id          IN NUMBER,
                            p_po_line_id            IN NUMBER,
                            p_po_line_location_id   IN NUMBER)
        RETURN NUMBER;

    -- changes starts as per  Defect#672
    FUNCTION get_intransit_qty (p_shipment_line_id   IN NUMBER,
                                p_as_of_date         IN DATE,
                                p_region             IN VARCHAR2,
                                p_intransit_type     IN VARCHAR2, --Added for v1.5
                                p_source_type        IN VARCHAR2 --Added for v1.5
                                                                ) -- CCR0007979
        RETURN NUMBER;

    -- changes end as per  Defect#672
    PROCEDURE run_intransit_report (
        psqlstat                     OUT VARCHAR2,
        perrproc                     OUT VARCHAR2,
        p_inv_org_id              IN     NUMBER,
        p_region                  IN     VARCHAR2,
        p_as_of_date              IN     VARCHAR2,
        p_cost_type_id            IN     NUMBER,
        p_brand                   IN     VARCHAR2,
        p_show_color              IN     VARCHAR2,
        p_shipment_num            IN     VARCHAR2     --aded as per defect#672
                                                 ,
        p_show_supplier_details   IN     VARCHAR2 --, p_markup_rate_type in varchar2
                                                 --, p_elimination_org in varchar2
                                                 --, p_elimination_rate in varchar2
                                                 --, p_user_rate in number
                                                 ,
        p_source_type             IN     VARCHAR2,     --Added for change V1.5
        p_intransit_type          IN     VARCHAR2,     --Added for change V1.5
        p_debug_level             IN     NUMBER := NULL,
        p_material_cost_for_pos   IN     VARCHAR2                      -- V1.7
                                                 );

    /* ------------start V1.6 CCR0009519------------------------*/
    FUNCTION xxdo_cst_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_cst_mat_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION xxdo_cst_mat_oh_val_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;
/* ------------End V1.6 CCR0009519------------------------*/
END;
/
