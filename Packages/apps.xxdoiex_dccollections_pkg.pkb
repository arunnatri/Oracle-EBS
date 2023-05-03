--
-- XXDOIEX_DCCOLLECTIONS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOIEX_DCCOLLECTIONS_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 10-JUN-2011
    -- File Name               : Calling in XXDOIEX_AHOLD.fmb and  XXDOIEX_RHOLD.fmb
    -- Work Order Num          : Deckers Custom Collection from (DO_IEXRCALL.fmb)
    -- Incidetn                 : INC0089941
    -- Description             :
    -- Latest Version          : 1.1
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 10-JUN-2011        1.0         Vijaya Reddy         Initial development.
    -- 09-SEP-2011        1.1         Vijaya Reddy
    -------------------------------------------------------------------------------
    PROCEDURE get_apply_holds (pn_header_id       NUMBER,
                               pn_org_id          NUMBER,
                               pv_status      OUT VARCHAR2)
    AS
        lv_return_status      VARCHAR2 (30);
        lv_msg_data           VARCHAR2 (4000);
        ln_msg_count          NUMBER;
        lv_hold_source_rec    apps.oe_holds_pvt.hold_source_rec_type;
        ln_hold_id            NUMBER;                            -- DEFAULT 1;
        lv_hold_entity_code   VARCHAR2 (10) DEFAULT 'O';
        ln_header_id          NUMBER;
        p_errbuf              VARCHAR2 (200);
        p_retcode             VARCHAR2 (50);
        l_org_id              NUMBER;
    BEGIN
        --------------------------------------------------------------------------------
        -- QUERY TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        BEGIN
            SELECT hold_id
              INTO ln_hold_id
              FROM apps.oe_hold_definitions
             WHERE NAME = 'Deckers Custom Collection - Hold Applied';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_errbuf    := SQLCODE || SQLERRM;
                p_retcode   := -5;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Program Terminated Abruptly');
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'All Data is Not Processed');
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'HOLD_ID does not exists in OE_HOLD_DEFINITIONS '
                    || p_errbuf);
        END;

        lv_hold_source_rec                    := apps.oe_holds_pvt.g_miss_hold_source_rec;
        lv_hold_source_rec.hold_id            := ln_hold_id;
        lv_hold_source_rec.hold_entity_code   := lv_hold_entity_code;
        lv_hold_source_rec.hold_entity_id     := pn_header_id;
        lv_hold_source_rec.header_id          := pn_header_id;
        lv_return_status                      := NULL;
        lv_msg_data                           := NULL;
        ln_msg_count                          := NULL;
        --      apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
        --                                       apps.fnd_global.resp_id,
        --                                       apps.fnd_global.resp_appl_id
        --                                      );
        --      apps.mo_global.init ('AR');
        l_org_id                              := fnd_profile.VALUE ('ORG_ID');
        mo_global.set_policy_context ('S', l_org_id);
        apps.oe_holds_pub.apply_holds (p_api_version => 1.0, p_init_msg_list => apps.fnd_api.g_true, p_commit => apps.fnd_api.g_false, p_hold_source_rec => lv_hold_source_rec, x_return_status => lv_return_status, x_msg_count => ln_msg_count
                                       , x_msg_data => lv_msg_data);

        IF lv_return_status = apps.fnd_api.g_ret_sts_success
        THEN
            pv_status   := 'Sucess';
            COMMIT;
        ELSIF lv_return_status IS NULL
        THEN
            pv_status   := 'Status is Nulll';
        ELSE
            pv_status   := 'Failure';
        END IF;
    END;

    PROCEDURE get_release_holds (pn_header_id       NUMBER,
                                 pn_org_id          NUMBER,
                                 pv_status      OUT VARCHAR2)
    AS
        ln_header_id             NUMBER;
        ln_hold_source_id        NUMBER;
        ln_hold_id               NUMBER;
        lv_return_status         VARCHAR2 (30);
        lv_msg_data              VARCHAR2 (4000);
        ln_msg_count             NUMBER;
        ln_order_tbl             apps.oe_holds_pvt.order_tbl_type;
        p_errbuf                 VARCHAR2 (200);
        p_retcode                VARCHAR2 (50);
        l_org_id                 NUMBER;

        --------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        CURSOR c_salsord_rhold_cur (cp_header_id IN NUMBER)
        IS
            SELECT /*+ index(hld OE_ORDER_HOLDS_ALL_N1) index(hsrc OE_HOLD_SOURCES_U1)*/
                   hdr.header_id, hsrc.hold_source_id, hsrc.hold_id
              FROM apps.oe_order_headers_all hdr, apps.oe_order_holds_all hld, apps.oe_hold_sources_all hsrc,
                   apps.oe_hold_definitions hdef
             WHERE     hdr.header_id = hld.header_id
                   AND hld.hold_source_id = hsrc.hold_source_id
                   AND hsrc.hold_id = hdef.hold_id
                   AND hdef.type_code = 'CREDIT'
                   AND hdr.header_id = cp_header_id;

        lv_release_reason_code   VARCHAR2 (240)
            := FND_PROFILE.VALUE ('XXDO_IEX_HOLD_REASON_CODE'); -- ADDED For DEFECT 330
    BEGIN
        --      apps.fnd_global.apps_initialize (apps.fnd_global.user_id,
        --                                       apps.fnd_global.resp_id,
        --                                       apps.fnd_global.resp_appl_id
        --                                      );
        --      apps.mo_global.init ('AR');
        l_org_id   := fnd_profile.VALUE ('ORG_ID');
        mo_global.set_policy_context ('S', l_org_id);

        FOR salsord_rhold IN c_salsord_rhold_cur (pn_header_id)
        LOOP
            ln_order_tbl (1).header_id   := salsord_rhold.header_id;
            lv_return_status             := NULL;
            lv_msg_data                  := NULL;
            ln_msg_count                 := NULL;
            apps.oe_holds_pub.release_holds (
                p_api_version           => 1.0,
                p_order_tbl             => ln_order_tbl,
                p_hold_id               => salsord_rhold.hold_id,
                --  p_release_reason_code      => 'VALID_CONFIG', Defect 330 11/2/2015
                p_release_reason_code   => lv_release_reason_code,
                p_release_comment       => 'Configuration is valid.',
                x_return_status         => lv_return_status,
                x_msg_count             => ln_msg_count,
                x_msg_data              => lv_msg_data);

            IF lv_return_status = apps.fnd_api.g_ret_sts_success
            THEN
                pv_status   := 'Sucess';
                COMMIT;
            ELSIF lv_return_status IS NULL
            THEN
                pv_status   := 'Status is Null';
            ELSE
                pv_status   := 'Failure';
            END IF;
        END LOOP;
    END;

    FUNCTION get_shipped_amt (p_header_id NUMBER)
        RETURN NUMBER
    IS
        p_ordremin_amt   NUMBER;
        --P_ordremin_amt2   NUMBER;
        p_errbuf         VARCHAR2 (200);
        p_retcode        VARCHAR2 (50);
    BEGIN
        /* Commented for defect 608 and added below
        SELECT NVL (SUM (oola.ordered_quantity * oola.unit_selling_price), 0)
                                                                ordered_line_amt
           INTO p_ordremin_amt
           FROM apps.oe_order_lines_all oola, apps.wsh_delivery_details wdd
          WHERE oola.header_id = wdd.source_header_id
            AND oola.line_id = wdd.source_line_id
            AND wdd.released_status IN ('C', 'I')
            AND oola.flow_status_code IN ('CANCELLED', 'CLOSED')
            AND oola.header_id = p_header_id;*/


        SELECT NVL (SUM (ROUND (NVL ((oola.unit_selling_price * oola.pricing_quantity), 0) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id))), 0) ordered_line_amt
          INTO p_ordremin_amt
          FROM apps.oe_order_lines_all oola
         WHERE     oola.flow_status_code IN ('CANCELLED', 'CLOSED')
               AND oola.header_id = p_header_id;

        /* SELECT NVL (SUM (oola.ordered_quantity * oola.unit_selling_price),
              0
             ) ordered_line_amt
          INTO P_ordremin_amt2
          FROM apps.oe_order_lines_all oola, apps.wsh_delivery_details wdd
          WHERE oola.header_id = wdd.source_header_id
          AND oola.line_id = wdd.source_line_id
          AND oola.flow_status_code  in ('CANCELLED','CLOSED')
          AND oola.header_id = p_header_id;*/

        -- RETURN (P_ordremin_amt1+P_ordremin_amt2);
        RETURN p_ordremin_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuf    := SQLCODE || SQLERRM;
            p_retcode   := -5;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS' || p_errbuf);
    END get_shipped_amt;

    FUNCTION get_total_order_amt (p_header_id NUMBER)
        RETURN NUMBER
    IS
        p_totalord_amt   NUMBER;
        p_errbuf         VARCHAR2 (200);
        p_retcode        VARCHAR2 (50);
    BEGIN
        /* Defect 608 commented and added below
        SELECT NVL (SUM (oola.ordered_quantity * oola.unit_selling_price), 0)
                                                                total_order_amt*/
        SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id))) total_order_amt
          INTO p_totalord_amt
          FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
         WHERE     ooha.header_id = oola.header_id
               AND ooha.header_id = p_header_id;

        RETURN p_totalord_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuf    := SQLCODE || SQLERRM;
            p_retcode   := -5;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS' || p_errbuf);
    END get_total_order_amt;

    FUNCTION validate_relhold (pn_user_id NUMBER)
        RETURN VARCHAR2
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 08-SEP-2011
    -- File Name               : Calling in XXDOIEX_RHOLD.fmb
    -- Work Order Num          : Deckers Custom Collection from (DO_IEXRCALL.fmb)
    -- Incidetn                 : INC0089941
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 08-SEP-2011        1.0         Vijaya Reddy         Initial development.
    --
    -------------------------------------------------------------------------------
    IS
        ----------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE  authorization responsibilities to RELEASE the HOLDS on sales orders
        ----------------------------------------------------------------------------------------------
        CURSOR c_valid_resp_cur IS
            SELECT a.responsibility_id
              FROM apps.oe_hold_authorizations a, apps.oe_hold_definitions b
             WHERE     a.hold_id = b.hold_id
                   AND b.NAME = 'Deckers Custom Collection - Hold Applied'
                   AND a.authorized_action_code = 'REMOVE'
                   AND ((SYSDATE BETWEEN NVL (a.start_date_active, SYSDATE) AND NVL (a.end_date_active, SYSDATE)) OR a.end_date_active IS NULL);

        lv_rel_flag   VARCHAR2 (1);
    BEGIN
        lv_rel_flag   := NULL;

        FOR valid_resp IN c_valid_resp_cur
        LOOP
            IF apps.fnd_global.resp_id = valid_resp.responsibility_id
            THEN
                lv_rel_flag   := 'Y';
                RETURN lv_rel_flag;
            ELSE
                lv_rel_flag   := 'N';
            END IF;
        END LOOP;

        RETURN lv_rel_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN lv_rel_flag;
    END;
/*FUNCTION  VALIDATE_APPLYHOLD(pn_user_id NUMBER) RETURN VARCHAR2
--------------------------------------------------------------------------------
-- Created By              : Vijaya Reddy ( Suneara Technologies )
-- Creation Date           : 09-SEP-2011
-- File Name               : Calling in XXDOIEX_AHOLD.fmb and XXDOIEX_AHOLDSGFF
-- Work Order Num          : Deckers Custom Collection from (DO_IEXRCALL.fmb)
-- Incidetn                 : INC0089941
-- Description             :
-- Latest Version          : 1.0
--
-- Revision History:
-- =============================================================================
-- Date               Version#    Name            Remarks
-- =============================================================================
-- 09-SEP-2011        1.0         Vijaya Reddy         Initial development.
--
-------------------------------------------------------------------------------
IS
   ------------------------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE  authorization responsibilities to APPLY the HOLDS on sales orders
   ------------------------------------------------------------------------------------------------

   CURSOR c_valid_resp_cur IS
   SELECT a.responsibility_id
         FROM apps.oe_hold_authorizations a, apps.oe_hold_definitions b
            WHERE a.hold_id = b.hold_id
             AND b.name = 'Deckers Custom Collection - Hold Applied'
             AND a.authorized_action_code = 'APPLY'
             AND ((SYSDATE BETWEEN NVL (a.start_date_active, SYSDATE)
                        AND NVL (a.end_date_active, SYSDATE)) OR a.end_date_active IS NULL );

lv_rel_flag VARCHAR2(1);


BEGIN


  lv_rel_flag := NULL;

   FOR valid_resp IN c_valid_resp_cur
   LOOP

    IF APPS.FND_GLOBAL.RESP_ID= VALID_RESP.RESPONSIBILITY_ID THEN
     lv_rel_flag:='Y';
     RETURN lv_rel_flag;
    ELSE
     lv_rel_flag:='N';
    END IF;
  END LOOP;

RETURN lv_rel_flag;

EXCEPTION
WHEN OTHERS THEN
 RETURN lv_rel_flag;
END ;*/
END xxdoiex_dccollections_pkg;
/
