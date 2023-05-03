--
-- XXD_INV_GIVR_SNAP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_GIVR_SNAP_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  GIVR Capture Cost Snapshot - Deckers                             *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  15-JUL-2020                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     15-JUL-2020  Srinath Siricilla     Initial Creation CCR0008682         *
      * 1.1     28-JAN-2021  Showkath Ali          CCR0008986                          *
      * 1.2     17-SEP-2021  Showkath Ali          CCR0009608                          *
      *********************************************************************************/
    PROCEDURE LOAD_CST_VIEW_TBL_PRC (p_region            IN VARCHAR2,
                                     p_organization_id   IN NUMBER);

    PROCEDURE LOAD_CST_MMT_TBL_PRC (p_date IN DATE);

    PROCEDURE UPD_CST_MMT_TBL_PRC;

    PROCEDURE INS_CST_HIST_DTLS_TBL_PRC (p_date IN DATE);

    FUNCTION XXD_CST_MAT_OH_FNC (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION XXD_CST_MAT_FNC (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER;

    FUNCTION XXD_GET_SNAP_ITEM_COST_FNC (pv_cost                IN VARCHAR2,
                                         pn_organization_id        NUMBER,
                                         pn_inventory_item_id      NUMBER,
                                         pv_custom_cost         IN VARCHAR2,
                                         p_date                 IN DATE)
        RETURN NUMBER;

    --1.1 changes start
    FUNCTION get_item_elements_fnc (pn_inventory_item_id IN NUMBER, pn_organization_id IN NUMBER, P_type IN VARCHAR2)
        -- 1.1 changes end
        RETURN NUMBER;

    PROCEDURE MAIN (errbuf                 OUT NOCOPY VARCHAR2,
                    retcode                OUT NOCOPY VARCHAR2,
                    p_as_of_date        IN            VARCHAR2,
                    p_snapshot_date     IN            VARCHAR2,          --1.1
                    p_region            IN            VARCHAR2,          --1.2
                    p_organization_id   IN            NUMBER             --1.2
                                                            );
END XXD_INV_GIVR_SNAP_PKG;
/
