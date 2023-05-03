--
-- XXDO_ONT_RMA_HOLD_RELEASE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_RMA_HOLD_RELEASE_PKG"
AS
    /*
     **********************************************************************************************
       $Header:  XXDO_ONT_RMA_HOLD_RELEASE_PKG.sql   1.0    2017/03/24   10:00:00   Infosys $
       **********************************************************************************************
       */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  XXDO_ONT_RMA_HOLD_RELEASE_PKG
    --
    -- Description  :  This is package  for WMS to EBS RMA Hold Release Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 24-Mar-2017   Infosys            1.0       Created
    -- ***************************************************************************

    /** ****************************************************************************
   -- Procedure Name      :  get_resp_details
   -- Description         :  This procedure is to get responsibility details
   -- Parameters          : p_resp_id      OUT : Responsibility ID
   --                      p_resp_appl_id     OUT : Application ID
   -
   -- Return/Exit         :  none  --
   --
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date          author             Version  Description
   -- ------------  -----------------  -------
   -- 24-Mar-2017 Infosys            1.0  Initial Version.
   ***************************************************************************/

    PROCEDURE get_resp_details (p_org_id         IN     NUMBER,
                                p_resp_id           OUT NUMBER,
                                p_resp_appl_id      OUT NUMBER)
    IS
        lv_mo_resp_id        NUMBER;
        lv_mo_resp_appl_id   NUMBER;
        lv_const_ou_name     VARCHAR2 (200);
        lv_var_ou_name       VARCHAR2 (200);
    BEGIN
        BEGIN
            SELECT resp.responsibility_id, resp.application_id
              INTO lv_mo_resp_id, lv_mo_resp_appl_id
              FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
             WHERE     flv.lookup_code = UPPER (hou.name)
                   AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND language = 'US'
                   AND hou.organization_id = p_org_id
                   AND flv.description = resp.responsibility_name
                   AND end_date_active IS NULL
                   AND end_date IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_resp_id        := NULL;
                p_resp_appl_id   := NULL;
        END;

        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

    /** ****************************************************************************
   -- Procedure Name      :  main
   -- Description         :  This procedure is to check and release hold based on RA
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date          author             Version  Description
   -- ------------  -----------------  -------
   -- 24-Mar-2017 Infosys            1.0  Initial Version.
   ***************************************************************************/
    PROCEDURE main (errbuf         OUT VARCHAR2,
                    retcode        OUT NUMBER,
                    p_rma_num   IN     VARCHAR2)
    IS
        --cursor to check for hold qty based on RA
        CURSOR c_rma_hold IS
              SELECT DISTINCT hp.party_name, oh.header_id, SUM (ol.ordered_quantity) quantity
                FROM apps.oe_order_holds_all ooha, apps.oe_hold_sources_all ohsa, apps.oe_hold_definitions ohd,
                     apps.oe_order_lines_all ol, apps.oe_order_headers_all oh, apps.hz_cust_accounts hca,
                     apps.hz_parties hp
               WHERE     ooha.hold_source_id = ohsa.hold_source_id
                     AND ohsa.hold_id = ohd.hold_id
                     AND oh.sold_to_org_id = hca.cust_account_id
                     AND hca.party_id = hp.party_id
                     AND oh.order_number = NVL (p_rma_num, oh.order_number)
                     AND ooha.line_id = ol.line_id
                     AND ooha.released_flag = 'N'
                     AND oh.header_id = ooha.header_id
            GROUP BY hp.party_name, oh.header_id;

        CURSOR c_rma_lines (p_header_id NUMBER)
        IS
              SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.NAME AS hold_name, hold_defs.type_code,
                     holds.header_id, holds.org_id hold_org_id, holds.line_id,
                     ol.ordered_quantity, holds.ORDER_HOLD_ID, hold_srcs.hold_id
                FROM oe_hold_definitions hold_defs, oe_hold_sources_all hold_srcs, /*OU_BUG replaced wih tables _all*/
                                                                                   oe_order_holds_all holds,
                     oe_order_lines_all ol
               /*OU_BUG replaced wih tables _all*/
               WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                     AND hold_defs.hold_id = hold_srcs.hold_id
                     AND holds.released_flag = 'N'
                     AND ol.line_id = holds.line_id
                     AND holds.header_id = p_header_id
            ORDER BY ol.ordered_quantity ASC;

        --local variables
        l_released_qty         NUMBER;
        l_qty_check            NUMBER;
        ln_threshold_qty       NUMBER;
        l_order_tbl            OE_HOLDS_PVT.order_tbl_type;
        x_return_status        VARCHAR2 (30);
        x_msg_data             VARCHAR2 (256);
        x_msg_count            NUMBER;
        x_msg_index_out        NUMBER;
        in_chr_reason          VARCHAR2 (50) := 'CS-REL';
        lv_lookup_code         VARCHAR2 (50);
        l_validation_flag      VARCHAR2 (2);
        ln_org_id              NUMBER;
        l_num_resp_id          NUMBER;
        l_num_resp_appl_id     NUMBER;
        l_release_qty          NUMBER := 0;
        l_tot_hold_rel_qty     NUMBER := 0;
        l_hold_release_rec     oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec      oe_holds_pvt.hold_source_rec_type;
        p_io_hold_source_tbl   OE_HOLDS_PVT.order_tbl_type;
    BEGIN
        l_validation_flag   := 'Y';

        --open cursor c_rma_hold
        FOR r_rma_hold IN c_rma_hold
        LOOP
            SELECT SUM (ol.ordered_quantity) quantity
              INTO l_released_qty
              FROM apps.oe_order_holds_all ooha, apps.oe_hold_sources_all ohsa, apps.oe_hold_definitions ohd,
                   apps.oe_order_lines_all ol
             WHERE     ooha.hold_source_id = ohsa.hold_source_id
                   AND ohsa.hold_id = ohd.hold_id
                   AND ol.header_id = r_rma_hold.header_id
                   AND ooha.released_flag = 'Y'
                   AND ol.line_id = ooha.line_id;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Qty already released for the RMA '
                || p_rma_num
                || ' is : '
                || l_released_qty);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Qty on hold for the RMA '
                || p_rma_num
                || ' is : '
                || r_rma_hold.quantity);

            /*Checking lookup code for particular RA*/
            BEGIN
                SELECT lookup_code
                  INTO lv_lookup_code
                  FROM fnd_lookup_values fvl
                 WHERE     fvl.lookup_type = 'XXDONT_RA_HOLD_THRESHOLD_LKP'
                       AND NVL (LANGUAGE, USERENV ('LANG')) =
                           USERENV ('LANG')
                       AND fvl.enabled_flag = 'Y'
                       AND lookup_code = r_rma_hold.party_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_lookup_code   := NULL;
            -- l_validation_flag:='N';
            END;

            /*getting threshold value according to the account*/
            IF lv_lookup_code IS NOT NULL
            THEN
                SELECT meaning
                  INTO ln_threshold_qty
                  FROM fnd_lookup_values fvl
                 WHERE     fvl.lookup_type = 'XXDONT_RA_HOLD_THRESHOLD_LKP'
                       AND NVL (LANGUAGE, USERENV ('LANG')) =
                           USERENV ('LANG')
                       AND fvl.enabled_flag = 'Y'
                       AND lookup_code = r_rma_hold.party_name;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Account threshold qty is ' || ln_threshold_qty);
            ELSE
                SELECT meaning
                  INTO ln_threshold_qty
                  FROM fnd_lookup_values fvl
                 WHERE     fvl.lookup_type = 'XXDONT_RA_HOLD_THRESHOLD_LKP'
                       AND NVL (LANGUAGE, USERENV ('LANG')) =
                           USERENV ('LANG')
                       AND fvl.enabled_flag = 'Y'
                       AND lookup_code = 'ALL';

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Default threshold qty is ' || ln_threshold_qty);
            END IF;

            l_qty_check   := ln_threshold_qty - NVL (l_released_qty, 0);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Qty which can be released for the RMA '
                || p_rma_num
                || ' is : '
                || l_qty_check);

            IF (l_qty_check <= ln_threshold_qty)
            THEN
                IF l_validation_flag = 'Y'
                THEN
                    /* releasing hold*/
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validation flag is   ' || l_validation_flag);

                    IF (r_rma_hold.quantity > l_qty_check)
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Quantity '
                            || r_rma_hold.quantity
                            || ' cannot be released. Can release only quantity '
                            || l_qty_check);
                    END IF;

                    --oe_debug_pub.setdebuglevel(10);
                    /*  fnd_global.apps_initialize (
                    user_id        => fnd_profile.VALUE ('USER_ID'),
                    resp_id        => fnd_profile.VALUE ('RESP_ID'),
                    resp_appl_id   => fnd_profile.VALUE ('RESP_APPL_ID'));
                    oe_msg_pub.initialize;*/
                    SELECT org_id
                      INTO ln_org_id
                      FROM apps.oe_order_headers_all a
                     WHERE header_id = r_rma_hold.header_id;

                    get_resp_details (ln_org_id,
                                      l_num_resp_id,
                                      l_num_resp_appl_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Responsibility ID '
                        || l_num_resp_id
                        || ' Resp Application ID '
                        || l_num_resp_appl_id);
                    apps.fnd_global.apps_initialize (
                        user_id        => fnd_profile.VALUE ('USER_ID'),
                        resp_id        => l_num_resp_id,
                        resp_appl_id   => l_num_resp_appl_id);
                    mo_global.init ('ONT');

                    --  mo_global.set_policy_context('S',fnd_profile.value('ORG_ID'));
                    FOR holds_rec IN c_rma_lines (r_rma_hold.header_id)
                    LOOP
                        l_release_qty   :=
                            l_release_qty + holds_rec.ordered_quantity;

                        IF (l_release_qty <= l_qty_check)
                        THEN
                            --  l_cnt := l_cnt + 1;
                            l_order_tbl (1).header_id   :=
                                holds_rec.header_id;
                            l_order_tbl (1).line_id   := holds_rec.line_id;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Before calling HOLD RELEASE API...');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Qty for releasing HOLD : ' || holds_rec.ordered_quantity);
                            Oe_Holds_Pub.Release_Holds (
                                p_api_version           => 1.0,
                                p_init_msg_list         => Fnd_Api.G_FALSE,
                                p_commit                => Fnd_Api.G_FALSE,
                                p_validation_level      =>
                                    Fnd_Api.G_VALID_LEVEL_FULL,
                                p_order_tbl             => l_order_tbl,
                                p_hold_id               => holds_rec.hold_id,
                                p_release_reason_code   => in_chr_reason,
                                p_release_comment       =>
                                       'Release Date '
                                    || TRUNC (SYSDATE)
                                    || 'Qty is less then Thresold value',
                                x_return_status         => x_return_status,
                                x_msg_count             => x_msg_count,
                                x_msg_data              => x_msg_data);

                            IF x_return_status != 'S'
                            THEN
                                FOR i IN 1 .. x_msg_count
                                LOOP
                                    OE_MSG_PUB.get (
                                        p_msg_index       => i,
                                        p_encoded         => 'F',
                                        p_data            => x_msg_data,
                                        p_msg_index_out   => x_msg_index_out);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Failure msg' || x_msg_data);
                                END LOOP;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Failure msg' || x_msg_data);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       '===> ********** Error ******* Hold was not Released - '
                                    || x_msg_data);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Msg data is ' || x_msg_data);
                                ROLLBACK;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Hold Released for Header ID : '
                                    || l_order_tbl (1).header_id
                                    || ' Line ID : '
                                    || l_order_tbl (1).line_id);
                                COMMIT;
                            END IF;
                        --exit when l_cnt=1;
                        END IF;
                    END LOOP;
                END IF;
            END IF;

            IF l_released_qty = ln_threshold_qty
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'RMA '
                    || p_rma_num
                    || ' has reached the maximum threshold quantity :'
                    || ln_threshold_qty);
            END IF;
        -- l_cnt:=0;
        END LOOP;                                    --close cursor c_rma_hold
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
    END main;
END;
/
