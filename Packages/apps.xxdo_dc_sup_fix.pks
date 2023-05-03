--
-- XXDO_DC_SUP_FIX  (Package) 
--
--  Dependencies: 
--   XXDO_DC_SUPPORT_FIX_AUDIT (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_DC_SUP_FIX"
AS
    /******************************************************************************/
    /* Name       : Package XXDO_DC_SUP_FIX
    /* Created by : Infosys Ltd
    /* Created On : 8/16/2016
    /* Description: Package to bundle all data fix related to LPN in WMS Org.
    /******************************************************************************/
    /*Intialize global parameters*/

    g_invalid_excpn   EXCEPTION;
    g_err_buf         VARCHAR2 (600);
    g_audit_rec       XXDO_DC_SUPPORT_FIX_AUDIT%ROWTYPE;


    /******************************************************************************/
    /* Name         : WRITE_LOG
    /* Description  : Procedure to write log
    /******************************************************************************/
    PROCEDURE WRITE_LOG (P_MSG IN VARCHAR2);

    /******************************************************************************/
    /* Name         : INSERT_AUDIT
    /* Description  : Procedure to record changes
    /******************************************************************************/
    PROCEDURE INSERT_AUDIT (p_out_error_buff   OUT VARCHAR2,
                            p_out_error_code   OUT NUMBER);

    /******************************************************************************/
    /* Name         : LPN_UPDATE_FIX
    /* Description  : Procedure to fix WMS_LICENSE_PLATE_NUMBERS related records
    /******************************************************************************/
    PROCEDURE LPN_UPDATE_FIX (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER, P_ORG_ID IN NUMBER, P_SUBINV IN VARCHAR2, P_LOC_ID IN NUMBER
                              , P_LPN_CONTEXT IN NUMBER, P_IN_PARENT_LPN IN NUMBER, P_IN_OUTERMOST_LPN IN NUMBER);

    /******************************************************************************/
    /* Name         : MOQD_UPDATE_FIX
    /* Description  : Procedure to fix MTL_ONHAND_QUANTITIES_DETAIL related records
    /******************************************************************************/
    PROCEDURE MOQD_UPDATE_FIX (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER, P_ORG_ID IN NUMBER, P_SUBINV IN VARCHAR2, P_LOC_ID IN NUMBER
                               , P_IN_LPN IN NUMBER);

    /******************************************************************************/
    /* Name         : MMTT_UPDATE_FIX
    /* Description  : Procedure to fix MTL_MATERIAL_TRANSATIONS_TEMP related records
    /******************************************************************************/
    PROCEDURE MMTT_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                               p_out_error_code      OUT NUMBER,
                               P_ID               IN     NUMBER,
                               P_ORG_ID           IN     NUMBER,
                               P_SUBINV           IN     VARCHAR2,
                               P_LOC_ID           IN     NUMBER,
                               P_IN_LPN           IN     NUMBER,
                               P_TRANSFER_LPN     IN     NUMBER);

    /******************************************************************************/
    /* Name         : WDD_UPDATE_FIX
    /* Description  : Procedure to fix WSH_DELIVERY_DETAIL related records
    /******************************************************************************/
    PROCEDURE WDD_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                              p_out_error_code      OUT NUMBER,
                              P_ID               IN     NUMBER,
                              P_ORG_ID           IN     NUMBER,
                              P_SUBINV           IN     VARCHAR2,
                              P_LOC_ID           IN     NUMBER);

    /******************************************************************************/
    /* Name         : MTR_UPDATE_FIX
    /* Description  : Procedure to fix MTL_RESERVATIONS related records
    /******************************************************************************/
    PROCEDURE MTR_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                              p_out_error_code      OUT NUMBER,
                              P_ID               IN     NUMBER,
                              P_ORG_ID           IN     NUMBER,
                              P_SUBINV           IN     VARCHAR2,
                              P_LOC_ID           IN     NUMBER);

    /******************************************************************************/
    /* Name         : MTRH_PYRAMID_PUSH
    /* Description  : Procedure to fix push wave into PYRAMID (US3)
    /******************************************************************************/
    PROCEDURE MTRH_PYRAMID_PUSH (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER
                                 , P_ORG_ID IN NUMBER);

    /******************************************************************************/
    /* Name         : RSH_3PL_ASN_RESENT
    /* Description  : Procedure to resent ASN to 3PL
    /******************************************************************************/
    PROCEDURE RSH_3PL_ASN_RESENT (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER);

    /******************************************************************************/
    /* Name         : DELETE_DO_DEBUG
    /* Description  : Procedure to delete do_debug records
    /******************************************************************************/
    PROCEDURE DELETE_DO_DEBUG (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_LOOKBACK_DAYS IN NUMBER);

    /******************************************************************************/
    /* Name         : MAIN_PROC
    /* Description  : Procedure to fix MTL_RESERVATIONS related records
    /******************************************************************************/
    PROCEDURE MAIN_PROC (p_out_error_buff        OUT VARCHAR2,
                         p_out_error_code        OUT NUMBER,
                         P_INCIDENT           IN     VARCHAR2,
                         P_TABLE_NAME         IN     VARCHAR2,
                         P_HIDDEN_PARAM_1     IN     VARCHAR2,
                         P_SHIPMENT_ACTION    IN     VARCHAR2,
                         P_ID                 IN     NUMBER,
                         P_DELIVERY_ID        IN     NUMBER,
                         P_ORG_ID             IN     NUMBER,
                         P_SUBINV             IN     VARCHAR2,
                         P_LOC_ID             IN     NUMBER,
                         P_LPN_CONTEXT        IN     NUMBER,
                         P_IN_PARENT_LPN      IN     NUMBER,
                         P_IN_OUTERMOST_LPN   IN     NUMBER,
                         P_IN_LPN             IN     NUMBER,
                         P_TRANSFER_LPN       IN     NUMBER,
                         P_TRACKING_NUMBER    IN     VARCHAR2,
                         P_PRO_NUMBER         IN     VARCHAR2,
                         P_SCAC_CODE          IN     VARCHAR2,
                         P_LOAD_ID            IN     VARCHAR2,
                         P_WAYBILL            IN     VARCHAR2);

    /******************************************************************************/
    /* Name         : INSERT_CYCLE_COUNT_ITEMS
    /* Description  : Procedure to insert new items to mtl_cycle_count_items
    /******************************************************************************/
    PROCEDURE INSERT_CYCLE_COUNT_ITEMS (p_out_error_buff   OUT VARCHAR2,
                                        p_out_error_code   OUT NUMBER);

    /******************************************************************************/
    /* Name         : DELETE_PICKTICKET
    /* Description  : Procedure to delete Delivery from do_edi856_pick_tickets
    /******************************************************************************/
    PROCEDURE DELETE_PICKTICKET (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_shipment_id IN NUMBER
                                 , p_delivery_id IN NUMBER);

    /******************************************************************************/
    /* Name         : UPDATE_DELIVERY_INFO
    /* Description  : Procedure to delete Delivery from do_edi856_pick_tickets
    /******************************************************************************/
    PROCEDURE UPDATE_DELIVERY_INFO (p_out_error_buff       OUT VARCHAR2,
                                    p_out_error_code       OUT NUMBER,
                                    P_DELIVERY_ID       IN     NUMBER,
                                    P_TRACKING_NUMBER   IN     VARCHAR2,
                                    P_PRO_NUMBER        IN     VARCHAR2,
                                    P_SCAC_CODE         IN     VARCHAR2,
                                    P_LOAD_ID           IN     VARCHAR2,
                                    P_WAYBILL           IN     VARCHAR2);
END XXDO_DC_SUP_FIX;
/
