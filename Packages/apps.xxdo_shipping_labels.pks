--
-- XXDO_SHIPPING_LABELS  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SHIPPING_LABELS"
    AUTHID DEFINER
AS
    /********************************************************************************************
         Modification History:
        Version   SCN#        By                       Date             Comments

          1.0              BT-Technology Team          22-Nov-2014        Updated for BT
          1.1              Krishna Lavu               15-OCT-2017         CCR0006631 Delivery Download to Pyramid

     ******************************************************************************************/
    g_debug_pick                 NUMBER := 0;

    -- RETURN STATUSES
    G_RET_SUCCESS       CONSTANT VARCHAR2 (1) := APPS.FND_API.G_RET_STS_SUCCESS;
    G_RET_ERROR         CONSTANT VARCHAR2 (1) := APPS.FND_API.G_RET_STS_ERROR;
    G_RET_UNEXP_ERROR   CONSTANT VARCHAR2 (1)
                                     := APPS.FND_API.G_RET_STS_UNEXP_ERROR ;
    G_RET_WARNING       CONSTANT VARCHAR2 (1) := 'W';
    G_RET_INIT          CONSTANT VARCHAR2 (1) := 'I';

    -- CONCURRENT STATUSES
    G_FND_NORMAL        CONSTANT VARCHAR2 (20) := 'NORMAL';
    G_FND_WARNING       CONSTANT VARCHAR2 (20) := 'WARNING';
    G_FND_ERROR         CONSTANT VARCHAR2 (20) := 'ERROR';

    PROCEDURE create_maifest_label (p_delivery_id   IN     VARCHAR2,
                                    -- p_lang in varchar2,
                                    p_printer              VARCHAR2,
                                    x_ret_Stat         OUT VARCHAR2,
                                    x_message          OUT VARCHAR2,
                                    P_DEBUG_LEVEL          NUMBER := 0);

    PROCEDURE create_ws_manifest_label (p_delivery_id   IN     VARCHAR2,
                                        p_printer              VARCHAR2,
                                        x_ret_Stat         OUT VARCHAR2,
                                        x_message          OUT VARCHAR2,
                                        P_DEBUG_LEVEL          NUMBER := 0);

    PROCEDURE flagstaff_invoice (p_delivery_id   IN     NUMBER,
                                 -- p_lang in varchar2,
                                 p_printer              VARCHAR2,
                                 x_ret_Stat         OUT VARCHAR2,
                                 x_message          OUT VARCHAR2,
                                 P_DEBUG_LEVEL          NUMBER := 0);

    PROCEDURE wcs_print_manifest (p_lpn IN VARCHAR2, p_printer_task IN VARCHAR2:= NULL, p_printer_name IN VARCHAR2:= NULL
                                  , x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2, P_DEBUG_LEVEL NUMBER:= 0);

    PROCEDURE create_manifest_US (p_delivery_id   IN     VARCHAR2,
                                  p_printer              VARCHAR2,
                                  x_ret_Stat         OUT VARCHAR2,
                                  x_message          OUT VARCHAR2,
                                  P_DEBUG_LEVEL          NUMBER := 0);



    --Added new procedure as part of E-Comm Packing Slip Development on Jul-28-2014 by Sunera Technologies
    PROCEDURE get_packing_slip_details_all (p_delivery_id IN NUMBER, x_packing_slip_type OUT VARCHAR2, x_print_packslip OUT VARCHAR2, x_language_type OUT VARCHAR2, x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2
                                            , P_DEBUG_LEVEL NUMBER:= 0);

    FUNCTION get_vas_code (p_header_id        IN NUMBER,
                           p_line_id          IN NUMBER,
                           p_gift_wrap_flag      VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION print_pack_slip (p_delivery_id IN NUMBER)
        RETURN VARCHAR2;
END XXDO_SHIPPING_LABELS;
/
