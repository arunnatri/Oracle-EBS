--
-- XXDO_PO_DATE_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_DATE_UPDATE_PKG"
AS
    /*******************************************************************************
       * Program Name : xxdo_po_date_update_pkg
       * Language     : PL/SQL
       * Description  : This package is used by DECKARES PO DATE UPDATE form
       *
       * History      :
       *
       * WHO            WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- -----------------------------------
       * BT Technology          1.0 - Initial Version                                     MAR/11/2015
       * BT Technology          1.1 - Incremental Version                                APR/06/2015
     * BT Technology         1.2 - Factory Finished Date Column Addition Changes       MAY/29/2015
     * BT Technology         1.3 - Added WHO columns for UPDATE statement HPQC 2774    AUG/03/2015
        * GJensen              1.4 - Changed poll.closed code condition to allow for update to CLOSED FOR INVOICE lines Jun/16/17
        * GJensen            1.5 CCR0007334                                          JUL-20-2018
       * ---------------------------------------------------------------------------------------------- */
    PROCEDURE XXDO_UPDATE_REQ_DATE (P_HEADER_ID IN NUMBER, P_NEW_REQUEST_DATE IN DATE, P_ERROR_CODE OUT VARCHAR2
                                    , P_ERROR_TEXT OUT VARCHAR2)
    IS
        --variables for API
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        v_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        ----------------------
        ----------------------
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
        v_resp_appl_id                 NUMBER;
        v_resp_id                      NUMBER;
        v_user_id                      NUMBER;
    --
    BEGIN
        v_resp_appl_id              := fnd_global.resp_appl_id;
        v_resp_id                   := fnd_global.resp_id;
        v_user_id                   := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        APPS.mo_global.init ('PO');
        --
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        X_DEBUG_FILE                := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');
        oe_debug_pub.SetDebugLevel (5); -- Use 5 for the most debuging output, I warn  you its a lot of data
        --This is to CREATE an order header and an order line
        --Create Header record
        --Initialize header record to missing
        --
        l_header_rec                := oe_order_pub.g_miss_header_rec;
        l_header_rec.operation      := oe_globals.g_opr_update;
        l_header_rec.header_id      := p_header_id;     --pass order header id
        l_header_rec.Request_date   := P_NEW_REQUEST_DATE; --pass value with which the request date should be approved
        -- CALL TO PROCESS ORDER Check the return status and then commit.
        OE_ORDER_PUB.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl -- OUT PARAMETERS
                                                              ,
            x_header_rec               => v_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_Header_Adj_tbl           => x_Header_Adj_tbl,
            x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
            x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
            x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
            x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
            x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
            x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
            x_line_tbl                 => l_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_Line_Adj_tbl             => x_Line_Adj_tbl,
            x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
            x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
            x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
            x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
            x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
            x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
            x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
            x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
            x_action_request_tbl       => l_action_request_tbl);

        -- Retrieve messages
        -- Check the return status
        IF l_return_status = FND_API.G_RET_STS_SUCCESS
        --
        THEN
            P_ERROR_CODE   := 'S';
            p_error_text   := 'S';
        ELSE
            FOR i IN 1 .. l_msg_count
            LOOP
                Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);
            END LOOP;

            P_ERROR_CODE   := 'F';
            p_error_text   := l_msg_data;
        --
        END IF;
    END XXDO_UPDATE_REQ_DATE;

    --
    ---procedure to update need by date of PO line
    PROCEDURE XXDO_UPDATE_NEEDBY_DATE (
        p_po_num                      IN     VARCHAR2,
        P_PO_HEADER_ID                IN     NUMBER,
        P_STYLE                       IN     VARCHAR2,
        P_COLOR                       IN     VARCHAR2,
        P_SHIP_TO_LOCATION_ID         IN     NUMBER,
        P_SALES_ORDER_HEADER_ID       IN     NUMBER,
        P_PROMISED_DATE_OLD           IN     VARCHAR2,
        P_NEED_BY_DATE_OLD            IN     DATE,
        P_EX_FACTORY_DATE_OLD         IN     VARCHAR2,
        P_CONF_EX_FACTORY_DATE_OLD    IN     VARCHAR2,
        P_ORIG_FACTORY_DATE_OLD              VARCHAR2,
        --start of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
        P_FACTORY_FINISHED_DATE_OLD          VARCHAR2,
        --end of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
        p_new_promised_date           IN     VARCHAR2,
        p_new_needby_date             IN     VARCHAR2,
        p_org_id                      IN     NUMBER,
        p_error_code                     OUT VARCHAR2,
        p_error_num                      OUT NUMBER)
    IS
        v_resp_appl_id             NUMBER;
        v_resp_id                  NUMBER;
        v_user_id                  NUMBER;
        l_result                   NUMBER;
        V_LINE_NUM                 NUMBER;
        V_SHIPMENT_NUM             NUMBER;
        V_REVISION_NUM             NUMBER;
        V_line_location_id         NUMBER;
        l_api_errors               PO_API_ERRORS_REC_TYPE;

        --
        CURSOR LINE_LOCATION_SELECT IS
            SELECT POL.LINE_NUM, POLL.SHIPMENT_NUM
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                   po_distributions_all pda, MTL_CATEGORIES_B_kfv mcbk, MTL_CATEGORIES_B mcb,
                   mtl_item_categories mic, MTL_CATEGORY_SETS_VL MCS, AP_SUPPLIERS APS,
                   org_organization_definitions ood, mtl_parameters mp, FND_ID_FLEX_STRUCTURES ffs
             --CCR0007334 Optimized by removing outer joins and calling ne function
             /*  (SELECT DISTINCT hp.party_name,
                                oeh.order_number,
                                OEDSs.PO_HEADER_ID,
                                oedss.po_line_id,
                                oeh.header_id
                  FROM OE_ORDER_HEADERS_ALL oeh,
                       OE_ORDER_lineS_ALL ola,
                       hz_cust_accounts hca,
                       hz_parties hp,
                       APPS.OE_DROP_SHIP_sources OEDSs
                 --
                 --
                 WHERE     oeh.sold_to_org_id = hca.cust_account_id
                       AND hca.party_id = hp.party_id
                       AND oeh.header_id = ola.header_id
                       AND ola.line_id = oedss.line_id
                       AND oeh.header_id = oedss.header_id) SO_TAB,
               (SELECT DISTINCT hp1.party_name,
                                oeh1.order_number,
                                oeh1.header_id,
                                mtr.SUPPLY_SOURCE_HEADER_ID po_header_id,
                                mtr.SUPPLY_SOURCE_LINE_ID po_line_id,
                                oeh1.header_id header_id1
                  FROM OE_ORDER_HEADERS_ALL oeh1,
                       OE_ORDER_lineS_ALL ola1,
                       hz_cust_accounts hca1,
                       hz_parties hp1,
                       mtl_reservations mtr,
                       po_requisition_lines_all prla,
                       po_requisition_headers_all prha
                 --
                 WHERE     oeh1.sold_to_org_id = hca1.cust_account_id
                       AND hca1.party_id = hp1.party_id
                       AND oeh1.header_id = ola1.header_id
                       AND mtr.demand_source_line_id = ola1.line_id
                       AND prha.requisition_header_id =
                              prla.requisition_line_id
                       AND mtr.orig_supply_source_line_id =
                              prla.requisition_line_id
                       AND prha.InterFace_Source_Code = 'CTO') BTB_TAB*/
             --
             --End CCR0007334
             WHERE     poh.po_header_id = pol.po_header_id
                   AND pol.po_header_id = poll.po_header_id
                   AND pol.po_line_id = poll.po_line_id
                   AND pda.line_location_id = poll.line_location_id
                   AND pda.destination_organization_id = ood.organization_id
                   AND ood.organization_id = mp.organization_id
                   AND mcbk.category_id = pol.category_id
                   AND Pol.item_id = mic.inventory_item_id
                   AND ood.organization_id = mic.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.structure_id = ffs.id_flex_num
                   AND MCB.attribute_category = 'Item Categories'
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   AND poll.closed_code IN ('CLOSED FOR INVOICE', 'OPEN') --added from ver 1.2 to avoid bringing closed and cancelled lines
                   AND POH.VENDOR_ID = APS.VENDOR_ID
                   -- AND SO_TAB.PO_line_ID(+) = pol.po_line_id--CCR0007334
                   -- AND BTB_TAB.po_line_id(+) = pol.po_line_id--CCR0007334
                   AND POH.po_header_id = P_PO_HEADER_ID
                   AND (P_STYLE = mcb.attribute7 OR P_STYLE IS NULL)
                   AND (P_COLOR = mcb.attribute8 OR P_COLOR IS NULL)
                   AND (P_SHIP_TO_LOCATION_ID = POLL.ship_to_location_id OR P_SHIP_TO_LOCATION_ID IS NULL)
                   AND (P_SALES_ORDER_HEADER_ID = DO_PO_UTILS_PUB.get_po_line_header_id (pol.po_line_id) --CCR0007334
                                                                                                         OR P_SALES_ORDER_HEADER_ID IS NULL)
                   AND (TO_CHAR (TRUNC (poll.promised_date), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_PROMISED_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_PROMISED_DATE_OLD IS NULL)
                   AND (TO_CHAR (TRUNC (poll.need_by_date), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_NEED_BY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_NEED_BY_DATE_OLD IS NULL)
                   /*and ( to_char(TRUNC(to_DATE(poll.attribute4,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YY') = to_char(to_date(P_EX_FACTORY_DATE_OLD,'DD-MON-YY'),'DD-MON-YY') or P_EX_FACTORY_DATE_OLD is null)
                    and ( to_char(TRUNC(to_DATE(poll.attribute5,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YY') = to_char(to_date(P_CONF_EX_FACTORY_DATE_OLD,'DD-MON-YY'),'DD-MON-YY') or P_CONF_EX_FACTORY_DATE_OLD is null)
                    and ( to_char(TRUNC(to_DATE(poll.attribute8,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YY') = to_char(to_date(P_ORIG_FACTORY_DATE_OLD,'DD-MON-YY'),'DD-MON-YY') or P_ORIG_FACTORY_DATE_OLD is null) */
                   --and (to_char(trunc(to_DATE(poll.attribute4,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YYYY')= P_EX_FACTORY_DATE_OLD or P_EX_FACTORY_DATE_OLD is null)
                   --and ( to_char(trunc(to_DATE(poll.attribute5,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YYYY')= P_CONF_EX_FACTORY_DATE_OLD or P_CONF_EX_FACTORY_DATE_OLD is null)
                   -- and ( to_char(trunc(to_DATE(poll.attribute8,'YYYY/MM/DD HH24:MI:SS')),'DD-MON-YYYY') = P_ORIG_FACTORY_DATE_OLD or P_ORIG_FACTORY_DATE_OLD is null);
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute4), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_EX_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_EX_FACTORY_DATE_OLD IS NULL)
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute5), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_CONF_EX_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_CONF_EX_FACTORY_DATE_OLD IS NULL)
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute8), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_ORIG_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_ORIG_FACTORY_DATE_OLD IS NULL)
                   --start of changes by BT Tech for factory finished date--29-May-2015-ver 1.2
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute9), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_FACTORY_FINISHED_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_FACTORY_FINISHED_DATE_OLD IS NULL);

        --end of changes by BT Tech for factory finished date--29-May-2015-ver 1.2
        --
        --
        REC_LINE_LOCATION_SELECT   LINE_LOCATION_SELECT%ROWTYPE;
    BEGIN
        --
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        APPS.mo_global.init ('PO');

        --for REC_LINE_LOCATION_SELECT in LINE_LOCATION_SELECT
        --
        IF LINE_LOCATION_SELECT%ISOPEN
        THEN
            CLOSE LINE_LOCATION_SELECT;
        END IF;

        --
        OPEN LINE_LOCATION_SELECT;

        LOOP
            --
            FETCH LINE_LOCATION_SELECT INTO REC_LINE_LOCATION_SELECT;

            EXIT WHEN LINE_LOCATION_SELECT%NOTFOUND;

            --
            SELECT REVISION_NUM
              INTO V_REVISION_NUM
              FROM PO_HEADERS_ALL
             WHERE SEGMENT1 = p_po_num AND ORG_ID = P_ORG_ID;

            --
            V_LINE_NUM       := REC_LINE_LOCATION_SELECT.LINE_NUM;
            V_SHIPMENT_NUM   := REC_LINE_LOCATION_SELECT.SHIPMENT_NUM;

            --
            BEGIN
                l_result   :=
                    po_change_api1_s.update_po (
                        x_po_number             => p_po_num,
                        x_release_number        => NULL,
                        x_revision_number       => V_revision_num,
                        x_line_number           => V_LINE_NUM,
                        x_shipment_number       => V_SHIPMENT_NUM,
                        new_quantity            => NULL,
                        new_price               => NULL,
                        new_promised_date       => p_new_promised_date,
                        new_need_by_date        => p_new_needby_date,
                        launch_approvals_flag   => 'N',                     --
                        update_source           => NULL,
                        version                 => '1.0',
                        x_override_date         => NULL,
                        x_api_errors            => l_api_errors,
                        p_buyer_name            => NULL,
                        p_secondary_quantity    => NULL,
                        p_preferred_grade       => NULL,
                        p_org_id                => P_ORG_ID);
            EXCEPTION
                WHEN OTHERS
                THEN
                    P_ERROR_CODE   := 'When others API' || SQLERRM;
                    p_error_num    := 0;
                    RETURN;
            END;

            --
            p_error_num      := l_result;

            IF l_result <> 1
            THEN
                -- P_ERROR_CODE := 'cancel api error:';
                FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                LOOP
                    P_ERROR_CODE   :=
                        P_ERROR_CODE || l_api_errors.MESSAGE_TEXT (i);
                -- || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                EXIT;
            ELSE
                P_ERROR_CODE   := 'Need By Date Updated';
            --
            END IF;
        END LOOP;

        CLOSE LINE_LOCATION_SELECT;

        DBMS_OUTPUT.put_line ('3');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_num   := 2;
    --  ROLLBACK;
    END XXDO_UPDATE_NEEDBY_DATE;

    ---
    --Procedure to launch the PO Approval workflow for the PO which are updated by PO Update Date Form
    PROCEDURE XXDO_PO_APPROVAL (p_po_num IN VARCHAR2, P_org_id IN NUMBER, p_error_code OUT VARCHAR2
                                , P_ERROR_TEXT OUT VARCHAR2)
    IS
        l_api_errors             PO_API_ERRORS_REC_TYPE;
        v_po_header_id           NUMBER;
        v_org_id                 NUMBER;
        v_po_num                 VARCHAR2 (50);
        v_doc_type               VARCHAR2 (50);
        v_doc_sub_type           VARCHAR2 (50);
        l_return_status          VARCHAR2 (1);
        l_api_version   CONSTANT NUMBER := 2.0;
        l_api_name      CONSTANT VARCHAR2 (50) := 'UPDATE_DOCUMENT';
        g_pkg_name      CONSTANT VARCHAR2 (30) := 'PO_DOCUMENT_UPDATE_GRP';
        l_progress               VARCHAR2 (3) := '000';
        v_agent_id               NUMBER;
        ---
        v_item_key               VARCHAR2 (100);
        v_resp_appl_id           NUMBER;
        v_resp_id                NUMBER;
        v_user_id                NUMBER;
    --
    BEGIN
        v_org_id          := p_org_id;
        v_po_num          := p_po_num;

        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pdt.document_subtype,
                   pdt.document_type_code, pha.wf_item_key
              INTO v_po_header_id, v_agent_id, v_doc_sub_type, v_doc_type,
                                 v_item_key
              FROM apps.po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = v_org_id
                   AND pdt.document_type_code = 'PO'
                   AND segment1 = v_po_num;

            --
            l_progress   := '001';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_code   := 0;
        END;

        v_resp_appl_id    := fnd_global.resp_appl_id;
        v_resp_id         := fnd_global.resp_id;
        v_user_id         := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        APPS.mo_global.init ('PO');
        --calling seeded procedure to launch the po approval workflow
        --
        po_reqapproval_init1.start_wf_process (ItemType => 'POAPPRV', ItemKey => v_item_key, WorkflowProcess => 'XXDO_POAPPRV_TOP', ActionOriginatedFrom => 'PO_FORM', DocumentID => v_po_header_id -- po_header_id
                                                                                                                                                                                                   , DocumentNumber => v_po_num -- Purchase Order Number
                                                                                                                                                                                                                               , PreparerID => v_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                         , DocumentTypeCode => 'PO' --'PO'
                                                                                                                                                                                                                                                                                   , DocumentSubtype => 'STANDARD' --'STANDARD'
                                                                                                                                                                                                                                                                                                                  , SubmitterAction => 'APPROVE', forwardToID => NULL, forwardFromID => NULL, DefaultApprovalPathID => NULL, Note => NULL, PrintFlag => 'N', FaxFlag => 'N', FaxNumber => NULL, EmailFlag => 'N', EmailAddress => NULL, CreateSourcingRule => 'N', ReleaseGenMethod => 'N', UpdateSourcingRule => 'N', MassUpdateReleases => 'N', RetroactivePriceChange => 'N', OrgAssignChange => 'N', CommunicatePriceChange => 'N', p_Background_Flag => 'N', p_Initiator => NULL, p_xml_flag => NULL, FpdsngFlag => 'N'
                                               , p_source_type_code => NULL);
        --
        l_progress        := '002';
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        IF (l_return_status = 'S')
        THEN
            p_error_code   := 1;
            P_ERROR_TEXT   := 'S';
        --
        ELSE
            p_error_code   := 0;
            P_ERROR_TEXT   := 'F';
        END IF;

        l_progress        := '003';
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            p_error_code   := 0;
            p_error_text   := SQLERRM;
        WHEN OTHERS
        THEN
            p_error_text   := SQLERRM;
            p_error_code   := 0;
    END XXDO_PO_APPROVAL;

    --
    PROCEDURE FACTORY_DATE_UPDATE (p_po_num IN VARCHAR2, P_PO_HEADER_ID IN NUMBER, P_STYLE VARCHAR2, P_COLOR VARCHAR2, P_SHIP_TO_LOCATION_ID NUMBER, P_SALES_ORDER_HEADER_ID NUMBER, P_PROMISED_DATE_OLD VARCHAR2, P_NEED_BY_DATE_OLD DATE, P_EX_FACTORY_DATE_OLD DATE, P_CONF_EX_FACTORY_DATE_OLD DATE, P_ORIG_FACTORY_DATE_OLD DATE, --start of changes by BT Tech for factory finished date--29-May-2015
                                                                                                                                                                                                                                                                                                                                       P_FACTORY_FINISHED_DATE DATE, P_FACTORY_FINISHED_DATE_OLD DATE, --end of changes by BT Tech for factory finished date--29-May-2015
                                                                                                                                                                                                                                                                                                                                                                                                       P_EX_FACTORY_DATE IN DATE, P_CONF_EX_FACTORY_DATE IN DATE, P_ORIG_CONF_EX_FACTORY_DATE IN DATE, p_org_id IN NUMBER, p_error_code OUT VARCHAR2
                                   , p_error_num OUT NUMBER)
    IS
        CURSOR LINE_LOCATION_SELECT IS
            SELECT poll.line_location_id
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                   po_distributions_all pda, MTL_CATEGORIES_B_kfv mcbk, MTL_CATEGORIES_B mcb,
                   mtl_item_categories mic, MTL_CATEGORY_SETS_VL MCS, AP_SUPPLIERS APS,
                   org_organization_definitions ood, mtl_parameters mp, FND_ID_FLEX_STRUCTURES ffs
             --Start CCR0007334 Optimized by removing outer joins and calling function
             /*         (SELECT DISTINCT hp.party_name,
                                       oeh.order_number,
                                       OEDSs.PO_HEADER_ID,
                                       oedss.po_line_id,
                                       oeh.header_id
                         FROM OE_ORDER_HEADERS_ALL oeh,
                              OE_ORDER_lineS_ALL ola,
                              hz_cust_accounts hca,
                              hz_parties hp,
                              APPS.OE_DROP_SHIP_sources OEDSs
                        WHERE     oeh.sold_to_org_id = hca.cust_account_id
                              AND hca.party_id = hp.party_id
                              AND oeh.header_id = ola.header_id
                              AND ola.line_id = oedss.line_id
                              AND oeh.header_id = oedss.header_id) SO_TAB,
                      (SELECT DISTINCT hp1.party_name,
                                       oeh1.order_number,
                                       oeh1.header_id,
                                       mtr.SUPPLY_SOURCE_HEADER_ID po_header_id,
                                       mtr.SUPPLY_SOURCE_LINE_ID po_line_id,
                                       oeh1.header_id header_id1
                         FROM OE_ORDER_HEADERS_ALL oeh1,
                              OE_ORDER_lineS_ALL ola1,
                              hz_cust_accounts hca1,
                              hz_parties hp1,
                              mtl_reservations mtr,
                              po_requisition_lines_all prla,
                              po_requisition_headers_all prha
                        WHERE     oeh1.sold_to_org_id = hca1.cust_account_id
                              AND hca1.party_id = hp1.party_id
                              AND oeh1.header_id = ola1.header_id
                              AND mtr.demand_source_line_id = ola1.line_id
                              AND prha.requisition_header_id =
                                     prla.requisition_line_id
                              AND mtr.orig_supply_source_line_id =
                                     prla.requisition_line_id
                              AND prha.InterFace_Source_Code = 'CTO') BTB_TAB*/
             --end CCR0007334
             WHERE     poh.po_header_id = pol.po_header_id
                   AND pol.po_header_id = poll.po_header_id
                   AND pol.po_line_id = poll.po_line_id
                   AND pda.line_location_id = poll.line_location_id
                   AND pda.destination_organization_id = ood.organization_id
                   AND ood.organization_id = mp.organization_id
                   AND mcbk.category_id = pol.category_id
                   AND Pol.item_id = mic.inventory_item_id
                   AND ood.organization_id = mic.organization_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.structure_id = ffs.id_flex_num
                   AND MCB.attribute_category = 'Item Categories'
                   AND ffs.ID_FLEX_STRUCTURE_CODE = 'ITEM_CATEGORIES'
                   AND poll.closed_code IN ('CLOSED FOR INVOICE', 'OPEN') --added from ver 1.1 to avoid bringing closed and cancelled lines
                   AND POH.VENDOR_ID = APS.VENDOR_ID
                   --  AND SO_TAB.PO_line_ID(+) = pol.po_line_id--CCR0007334
                   --  AND BTB_TAB.po_line_id(+) = pol.po_line_id--CCR0007334
                   AND POH.SEGMENT1 = p_po_num
                   AND (P_STYLE = mcb.attribute7 OR P_STYLE IS NULL)
                   AND (P_COLOR = mcb.attribute8 OR P_COLOR IS NULL)
                   AND (P_SHIP_TO_LOCATION_ID = POLL.ship_to_location_id OR P_SHIP_TO_LOCATION_ID IS NULL)
                   AND (P_SALES_ORDER_HEADER_ID = DO_PO_UTILS_PUB.get_po_line_header_id (pol.po_line_id) --CCR0007334
                                                                                                         OR P_SALES_ORDER_HEADER_ID IS NULL)
                   AND (TO_CHAR (TRUNC (poll.promised_date), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_PROMISED_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_PROMISED_DATE_OLD IS NULL)
                   AND (TO_CHAR (TRUNC (poll.need_by_date), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_NEED_BY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_NEED_BY_DATE_OLD IS NULL)
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute4), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_EX_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_EX_FACTORY_DATE_OLD IS NULL)
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute5), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_CONF_EX_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_CONF_EX_FACTORY_DATE_OLD IS NULL)
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute8), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_ORIG_FACTORY_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_ORIG_FACTORY_DATE_OLD IS NULL)
                   --start of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
                   AND (TO_CHAR (TO_DATE (apps.fnd_date.canonical_to_date (poll.attribute9), 'DD-MON-YY'), 'DD-MON-YY') = TO_CHAR (TO_DATE (P_FACTORY_FINISHED_DATE_OLD, 'DD-MON-YY'), 'DD-MON-YY') OR P_FACTORY_FINISHED_DATE_OLD IS NULL);

        --end of changes by BT Tech for factory finished date--29-May-2015 ver 1.2

        --Start modification for Defect 2774,BT Technology Team,3-Aug-15
        gn_user_id             NUMBER := fnd_global.user_id;
        gn_login_id            NUMBER := fnd_global.login_id;
        gd_date                DATE := SYSDATE;
        ln_total_count         NUMBER := 0;

        TYPE line_location_type IS TABLE OF line_location_select%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_line_location_tab   line_location_type;
    --End  modification for Defect 2774,BT Technology Team,3-Aug-15


    BEGIN
        OPEN LINE_LOCATION_SELECT;

        FETCH LINE_LOCATION_SELECT BULK COLLECT INTO lt_line_location_tab;

        CLOSE LINE_LOCATION_SELECT;

        ln_total_count   := lt_line_location_tab.COUNT;

        IF ln_total_count > 0
        THEN
            FOR i IN lt_line_location_tab.FIRST .. lt_line_location_tab.LAST
            LOOP
                UPDATE po_line_locations_all poll
                   SET poll.attribute4 = TO_CHAR (TO_DATE (P_EX_FACTORY_DATE, 'DD/MON/YY'), 'YYYY/MM/DD'), --to_char(to_date(P_EX_FACTORY_DATE_OLD,'DD-MON-YY'),'DD-MON-YY'),--to_char(to_date(P_EX_FACTORY_DATE,'DD-MON-YYYY'),'DD-MON-YYYY'),
                                                                                                           poll.attribute5 = TO_CHAR (TO_DATE (P_CONF_EX_FACTORY_DATE, 'DD/MON/YY'), 'YYYY/MM/DD'), poll.attribute8 = TO_CHAR (TO_DATE (P_ORIG_CONF_EX_FACTORY_DATE, 'DD/MON/YY'), 'YYYY/MM/DD'), --'YYYY/MM/DD'
                       --start of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
                       --Commented out for CCR0007334
                       --  poll.attribute9 = to_char(to_date(P_FACTORY_FINISHED_DATE,'DD/MON/YY'),'YYYY/MM/DD'),--'YYYY/MM/DD'
                       --end of changes by BT Tech for factory finished date--29-May-2015 ver 1.2
                       --Start modification for Defect 2774,BT Technology Team,3-Aug-15
                       last_updated_by = gn_user_id, last_update_login = gn_login_id, last_update_date = gd_date
                 --Start modification for Defect 2774,BT Technology Team,3-Aug-15
                 WHERE     line_location_id =
                           lt_line_location_tab (i).line_location_id
                       AND poll.org_id = p_org_id
                       AND poll.po_header_id = P_PO_HEADER_ID;

                --Start modification for Defect 2774,BT Technology Team,18-Aug-15
                UPDATE po_headers_all poh
                   SET poh.last_updated_by = gn_user_id, poh.last_update_login = gn_login_id, poh.last_update_date = gd_date
                 WHERE     poh.po_header_id = P_PO_HEADER_ID
                       AND poh.org_id = p_org_id;

                UPDATE po_lines_all pol
                   SET pol.last_updated_by = gn_user_id, pol.last_update_login = gn_login_id, pol.last_update_date = gd_date
                 WHERE     pol.po_header_id = P_PO_HEADER_ID
                       AND pol.po_line_id IN
                               (SELECT po_line_id
                                  FROM po_line_locations_all poll
                                 WHERE     line_location_id =
                                           lt_line_location_tab (i).line_location_id
                                       AND poll.org_id = p_org_id)
                       AND pol.org_id = p_org_id;
            --End modification for Defect 2774,BT Technology Team,18-Aug-15

            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_code   := SQLERRM;
            p_error_code   := 0;
    END FACTORY_DATE_UPDATE;
END xxdo_po_date_update_pkg;
/
