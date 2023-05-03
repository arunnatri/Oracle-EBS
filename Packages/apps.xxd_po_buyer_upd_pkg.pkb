--
-- XXD_PO_BUYER_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_BUYER_UPD_PKG"
IS
    /********************************************************************************************
     * Package         : XXD_PO_BUYER_UPD_PKG
     * Description     : This package is used to update Buyer on Items and Open Purchase Orders
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------------
     * Date          Version#    Name                   Description
     *-------------------------------------------------------------------------------------------
     * 19-AUG-2020   1.0         Kranthi Bollam         Initial Version for CCR0008468
     *******************************************************************************************/

    --Global Variables
    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_PO_BUYER_UPD_PKG';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_conc_login_id     CONSTANT NUMBER := fnd_global.conc_login_id;
    gn_resp_id           CONSTANT NUMBER := fnd_profile.VALUE ('RESP_ID');
    gn_resp_appl_id      CONSTANT NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_parent_req_id     CONSTANT NUMBER := fnd_global.conc_priority_request;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_org_id            CONSTANT NUMBER := fnd_global.org_id;
    gv_brand                      VARCHAR2 (30) := NULL;
    gv_curr_active_season         VARCHAR2 (240) := NULL;
    gv_department                 VARCHAR2 (50) := NULL;
    gv_buyer_upd_on               VARCHAR2 (30) := NULL;
    gn_ou_id                      NUMBER := NULL;
    gv_po_date_from               VARCHAR2 (30) := NULL;
    gv_po_date_to                 VARCHAR2 (30) := NULL;
    gn_retcode                    NUMBER := NULL;
    gv_errbuf                     VARCHAR2 (2000) := NULL;
    gv_buy_season                 VARCHAR2 (30) := NULL;
    gv_buy_month                  VARCHAR2 (30) := NULL;

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
        lv_msg          VARCHAR2 (32767) := NULL;
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    --Procedure to Retain the data of last 10 runs and purge all other data
    PROCEDURE purge_data
    IS
        --Local Variables
        lv_proc_name   VARCHAR2 (30) := 'PURGE_DATA';
        lv_error_msg   VARCHAR2 (2000) := NULL;
    BEGIN
        msg ('START - Inside Purge Data Procedure', 'Y');
        msg (' ');
        msg ('START - Purge Items Staging table Data', 'Y');

        DELETE FROM
            xxdo.xxd_po_buyer_upd_items_stg_t
              WHERE     1 = 1
                    AND request_id IN
                            (SELECT request_id
                               FROM (SELECT request_id, RANK () OVER (ORDER BY request_id DESC) req_id_rank
                                       FROM (  SELECT request_id
                                                 FROM xxdo.xxd_po_buyer_upd_items_stg_t
                                             GROUP BY request_id) xx)
                              WHERE req_id_rank > 10);

        msg (' ');
        msg (
               'Number of Records Deleted/Purged from Item Staging table: '
            || SQL%ROWCOUNT,
            'Y');
        msg (' ');
        COMMIT;
        msg ('END - Purge Items Staging table Data', 'Y');
        msg (' ');

        msg ('START - Purge Purchase Orders Staging table Data', 'Y');

        DELETE FROM
            xxdo.xxd_po_buyer_upd_po_stg_t
              WHERE     1 = 1
                    AND request_id IN
                            (SELECT request_id
                               FROM (SELECT request_id, RANK () OVER (ORDER BY request_id DESC) req_id_rank
                                       FROM (  SELECT request_id
                                                 FROM xxdo.xxd_po_buyer_upd_po_stg_t
                                             GROUP BY request_id) xx)
                              WHERE req_id_rank > 10);

        msg (' ');
        msg (
               'Number of Records Deleted/Purged from Purchase Orders Staging table: '
            || SQL%ROWCOUNT,
            'Y');
        COMMIT;
        msg (' ');
        msg ('END - Purge Purchase Orders Staging table Data', 'Y');
        msg (' ');
        msg ('END - Inside Purge Data Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END purge_data;

    PROCEDURE get_po_for_buyer_upd (pn_ret_code   OUT NUMBER,
                                    pv_ret_msg    OUT VARCHAR2)
    IS
        --Local Variables
        lv_proc_name            VARCHAR2 (30) := 'GET_PO_FOR_BUYER_UPD';
        lv_error_msg            VARCHAR2 (2000) := NULL;
        lv_po_cur_stmt          VARCHAR2 (32627) := NULL;
        lv_po_select_clause     VARCHAR2 (10000) := NULL;
        lv_po_from_clause       VARCHAR2 (5000) := NULL;
        lv_po_where_clause      VARCHAR2 (10000) := NULL;
        lv_po_brand_cond        VARCHAR2 (5000) := NULL;
        lv_po_ou_cond           VARCHAR2 (5000) := NULL;
        lv_po_buy_season_cond   VARCHAR2 (5000) := NULL;
        lv_po_buy_month_cond    VARCHAR2 (5000) := NULL;
        lv_po_dt_cond           VARCHAR2 (5000) := NULL;
        lv_po_department_cond   VARCHAR2 (5000) := NULL;
        lv_po_date_from         VARCHAR2 (30) := NULL;
        lv_po_date_to           VARCHAR2 (30) := NULL;

        TYPE po_rec_type IS RECORD
        (
            operating_unit    VARCHAR2 (240),
            brand             VARCHAR2 (20),
            department        VARCHAR2 (50),
            po_number         VARCHAR2 (30),
            po_date           DATE,
            buy_season        VARCHAR2 (30),
            buy_month         VARCHAR2 (30),
            buyer_name        VARCHAR2 (120),
            new_buyer_name    VARCHAR2 (120),
            po_header_id      NUMBER,
            org_id            NUMBER,
            old_buyer_id      NUMBER,
            new_buyer_id      NUMBER,
            status            VARCHAR2 (30),
            error_message     VARCHAR2 (4000)
        );

        TYPE po_type IS TABLE OF po_rec_type
            INDEX BY BINARY_INTEGER;

        po_rec                  po_type;

        TYPE po_cur_typ IS REF CURSOR;

        po_cur                  po_cur_typ;
    BEGIN
        msg ('START - Get POs for Buyer Update Procedure', 'Y');
        lv_po_select_clause   := 'SELECT hou.name operating_unit
      ,po_det.brand
      ,po_det.department
      ,po_det.po_number
      ,po_det.po_date
      ,po_det.buy_season
      ,po_det.buy_month
      ,po_det.buyer_name buyer_name
      ,bm.new_buyer_name new_buyer_name
      ,po_det.po_header_id
      ,po_det.org_id
      ,po_det.old_buyer_id old_buyer_id
      ,bm.buyer_id new_buyer_id
      ,''NEW'' status
      ,NULL error_message
  ';

        lv_po_from_clause     :=
            'FROM (
       SELECT pha.agent_id old_buyer_id
             ,pav.agent_name buyer_name
             ,pla.attribute1 brand
             ,pla.attribute2 department
             ,pha.segment1 po_number
             ,pha.creation_date po_date
             ,pha.org_id
             ,pha.attribute8 buy_season
             ,pha.attribute9 buy_month
             ,pdt.type_name
             ,pdt.document_type_code
             ,pha.authorization_status
             ,pha.closed_code
             ,pha.po_header_id
             ,pha.type_lookup_code po_type
             ,pha.revision_num
         FROM apps.po_headers_all pha
             ,apps.po_agents_v pav
             ,apps.po_document_types_all pdt
             ,apps.po_lines_all pla
             ,apps.po_line_locations_all plla
        WHERE 1 = 1
          AND pha.agent_id = pav.agent_id
          AND pav.agent_name NOT LIKE ''VAS%''
          AND pha.org_id = pdt.org_id
          AND pdt.document_type_code IN (''PO'', ''PA'')
          AND pdt.document_subtype = pha.type_lookup_code
          AND NVL(pha.authorization_status, ''INCOMPLETE'') IN (
                                                              ''APPROVED''
                                                             ,''REQUIRES REAPPROVAL''
                                                             ,''INCOMPLETE''
                                                             ,''REJECTED''
                                                             ,''IN PROCESS''
                                                             ,''PRE-APPROVED''
                                                             )
          AND NVL(pha.cancel_flag, ''N'') <> ''Y''
          AND NVL(pha.frozen_flag, ''N'') <> ''Y''
          AND NVL(pha.closed_code, ''OPEN'') NOT IN (''CLOSED'', ''FINALLY CLOSED'')
          AND NVL(pla.closed_flag, ''N'') <> ''Y''
          AND pha.po_header_id = pla.po_header_id
          AND pla.po_header_id = plla.po_header_id
          AND pla.po_line_id = plla.po_line_id
          AND (plla.quantity - plla.quantity_received - plla.quantity_cancelled ) > 0
       GROUP BY                                                          
              pha.agent_id
             ,pav.agent_name
             ,pha.segment1
             ,pha.creation_date
             ,pha.org_id
             ,pha.attribute8
             ,pha.attribute9
             ,pdt.type_name
             ,pdt.document_type_code
             ,pha.authorization_status
             ,pha.closed_code
             ,pla.attribute1
             ,pla.attribute2
             ,pha.po_header_id
             ,pha.type_lookup_code
             ,pha.revision_num
       ) po_det,
       (
       SELECT DISTINCT
              flv.attribute1 brand
             ,flv.attribute2 department
             ,pa.agent_id buyer_id
             ,pa.agent_name new_buyer_name
         FROM apps.fnd_lookup_values flv
             ,apps.po_agents_v pa
        WHERE 1=1
          AND flv.lookup_type = ''DO_BUYER_CODE''
          AND flv.language = ''US''
          AND flv.enabled_flag = ''Y''
          AND SYSDATE BETWEEN NVL(flv.start_date_active, SYSDATE) AND NVL(flv.end_date_active, SYSDATE + 1)
          AND UPPER(flv.description) = UPPER(pa.agent_name)
          AND SYSDATE BETWEEN NVL(pa.start_date_active, SYSDATE) AND NVL(pa.end_date_active, SYSDATE + 1)
        ) bm,
        apps.hr_operating_units hou
 ';

        lv_po_where_clause    :=
            'WHERE 1=1
   AND po_det.brand = bm.brand
   AND po_det.department = DECODE(bm.department, ''ALL'', po_det.department, bm.department)
   AND NVL(po_det.old_buyer_id, 0) <> bm.buyer_id
   AND po_det.org_id = hou.organization_id
   ';

        --Brand Condition
        IF gv_brand = 'ALL'
        THEN
            lv_po_brand_cond   := 'AND 1=1
            ';
        ELSE
            lv_po_brand_cond   := 'AND po_det.brand = ''' || gv_brand || '''
            ';
        END IF;

        --PO Department Condition
        IF gv_department IS NULL OR gv_department = 'ALL'
        THEN
            lv_po_department_cond   := 'AND 1=1
            ';
        ELSE
            lv_po_department_cond   :=
                'AND po_det.department = ''' || gv_department || '''
            ';
        END IF;

        --Operating Unit Condition
        IF gn_ou_id IS NOT NULL
        THEN
            lv_po_ou_cond   := 'AND po_det.org_id = ' || gn_ou_id || '
            ';
        END IF;

        --Buy Season Unit Condition
        IF gv_buy_season IS NOT NULL
        THEN
            lv_po_buy_season_cond   :=
                'AND po_det.buy_season = ''' || gv_buy_season || '''
            ';
        END IF;

        --Buy Season Unit Condition
        IF gv_buy_month IS NOT NULL
        THEN
            lv_po_buy_month_cond   :=
                'AND po_det.buy_month = ''' || gv_buy_month || '''
            ';
        END IF;

        IF gv_po_date_from IS NULL OR gv_po_date_to IS NULL
        THEN
            lv_po_dt_cond   := 'AND 1=1
            ';
        ELSE
            lv_po_date_from   :=
                   TO_CHAR (
                       TO_DATE (gv_po_date_from, 'RRRR/MM/DD HH24:MI:SS'),
                       'RRRR/MM/DD')
                || ' 00:00:00';
            lv_po_date_to   :=
                   TO_CHAR (TO_DATE (gv_po_date_to, 'RRRR/MM/DD HH24:MI:SS'),
                            'RRRR/MM/DD')
                || ' 23:59:59';
            lv_po_dt_cond   :=
                   'AND po_det.po_date BETWEEN TO_DATE('''
                || lv_po_date_from
                || ''',''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE('''
                || lv_po_date_to
                || ''',''RRRR/MM/DD HH24:MI:SS'') 
            ';
        END IF;

        --Building the Final Query
        lv_po_cur_stmt        :=
               lv_po_select_clause
            || lv_po_from_clause
            || lv_po_where_clause
            || lv_po_brand_cond
            || lv_po_department_cond
            || lv_po_buy_season_cond
            || lv_po_buy_month_cond
            || lv_po_ou_cond
            || lv_po_dt_cond;
        msg ('-------------------------------------------------');
        msg ('POs Main Query(lv_po_cur_stmt)');
        msg ('-------------------------------------------------');
        msg (lv_po_cur_stmt || ';');
        msg ('-------------------------------------------------');

        --Opening the POs Cursor for the above sql statement(lv_po_cur_stmt)
        BEGIN
            OPEN po_cur FOR lv_po_cur_stmt;

            FETCH po_cur BULK COLLECT INTO po_rec;

            CLOSE po_cur;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg   :=
                    SUBSTR (
                           'Error while opening the cursor to get POs. So exiting the program and completing in WARNING. Error is:'
                        || SQLERRM,
                        1,
                        2000);
                msg (lv_error_msg);
                pn_ret_code   := gn_warning;
                pv_ret_msg    := lv_error_msg;
                RETURN;                                  --Exiting the program
        END;

        msg ('Count of POs for Buyer Update : ' || po_rec.COUNT);

        IF po_rec.COUNT <= 0
        THEN
            lv_error_msg   :=
                'No POs returned for the given parameters. So exiting the program and completing in WARNING.';
            msg (lv_error_msg);
            pn_ret_code   := gn_warning;
            pv_ret_msg    := lv_error_msg;
            RETURN;                                      --Exiting the program
        END IF;

        --Bulk Insert of POs into staging table
        FORALL i IN po_rec.FIRST .. po_rec.LAST
            INSERT INTO xxdo.xxd_po_buyer_upd_po_stg_t (operating_unit,
                                                        brand,
                                                        department,
                                                        po_number,
                                                        po_date,
                                                        buy_season,
                                                        buy_month,
                                                        buyer_name,
                                                        new_buyer_name,
                                                        po_header_id,
                                                        org_id,
                                                        old_buyer_id,
                                                        new_buyer_id,
                                                        status,
                                                        error_message,
                                                        request_id,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        last_update_login)
                 VALUES (po_rec (i).operating_unit, po_rec (i).brand, po_rec (i).department, po_rec (i).po_number, po_rec (i).po_date, po_rec (i).buy_season, po_rec (i).buy_month, po_rec (i).buyer_name, po_rec (i).new_buyer_name, po_rec (i).po_header_id, po_rec (i).org_id, po_rec (i).old_buyer_id, po_rec (i).new_buyer_id, po_rec (i).status, po_rec (i).error_message, gn_conc_request_id --request_id
                                                                                                                                                                                                                                                                                                                                                                                                   , SYSDATE --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                            , gn_user_id --created_by
                         , SYSDATE                          --last_update_date
                                  , gn_user_id               --last_updated_by
                                              , gn_login_id --last_update_login
                                                           );

        COMMIT;

        msg ('END - Get POs For Buyer Update Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END get_po_for_buyer_upd;

    --Procedure to Update Buyer on POs
    PROCEDURE buyer_upd_po
    IS
        CURSOR po_orgs_cur IS
              SELECT stg.org_id
                FROM xxdo.xxd_po_buyer_upd_po_stg_t stg
               WHERE     1 = 1
                     AND stg.request_id = gn_conc_request_id
                     AND NVL (stg.status, 'NEW') = 'NEW'
            GROUP BY stg.org_id
            ORDER BY stg.org_id;

        --POs Cursor
        CURSOR po_cur (cn_org_id IN NUMBER)
        IS
              SELECT *
                FROM xxdo.xxd_po_buyer_upd_po_stg_t stg
               WHERE     1 = 1
                     AND stg.request_id = gn_conc_request_id
                     AND NVL (stg.status, 'NEW') = 'NEW'
                     AND stg.org_id = cn_org_id
            ORDER BY stg.po_number;

        --Local Variables
        lv_proc_name        VARCHAR2 (30) := 'BUYER_UPD_PO';
        lv_error_msg        VARCHAR2 (2000) := NULL;
        ln_ret_code         NUMBER := NULL;
        lv_ret_msg          VARCHAR2 (2000) := NULL;
        ln_errors_cnt       NUMBER;
        excp_dml_errors     EXCEPTION;
        PRAGMA EXCEPTION_INIT (excp_dml_errors, -24381);
        lv_resp_name        VARCHAR2 (100)
                                := 'Deckers Purchasing User - Global';
        ln_application_id   NUMBER;
        ln_resp_id          NUMBER;
        lv_msg_data         VARCHAR2 (4000) := NULL;
        ln_msg_count        NUMBER;
        lv_return_status    VARCHAR2 (4000);
        ln_msg_index_out    NUMBER;
        lv_message_data     VARCHAR2 (2000);
    BEGIN
        msg ('START - Buyer Update On POs Procedure', 'Y');

        --Calling get_po_for_buyer_upd procedure which identifies the POs to be updated into POs staging table
        msg ('Calling GET_PO_FOR_BUYER_UPD procedure - START', 'Y');
        get_po_for_buyer_upd (pn_ret_code   => ln_ret_code,
                              pv_ret_msg    => lv_ret_msg);
        msg ('Calling GET_PO_FOR_BUYER_UPD procedure - END', 'Y');
        msg (' ');

        IF (ln_ret_code IS NOT NULL AND ln_ret_code <> gn_success)
        THEN
            gn_retcode   := ln_ret_code;
            gv_errbuf    := lv_ret_msg;
            RETURN;
        END IF;

        msg ('Updating Buyer on POs - START', 'Y');

        BEGIN
            SELECT application_id, responsibility_id
              INTO ln_application_id, ln_resp_id
              FROM apps.fnd_responsibility_vl
             WHERE 1 = 1 AND responsibility_name = lv_resp_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg   :=
                    SUBSTR (
                           'Could not get resp id and resp appl id for responsibility ::'
                        || lv_resp_name
                        || '. So exiting the program and completing in WARNING.',
                        1,
                        2000);
                msg (lv_error_msg);
                gn_retcode   := gn_warning;
                gv_errbuf    := lv_error_msg;
                RETURN;                                  --Exiting the program
        END;

        --Apps Initialization
        apps.fnd_global.apps_initialize (gn_user_id,
                                         ln_resp_id,
                                         ln_application_id);

        FOR po_orgs_rec IN po_orgs_cur
        LOOP
            mo_global.init ('PO');
            mo_global.set_policy_context ('S', po_orgs_rec.org_id);
            --Setup MO Operating Unit
            fnd_request.set_org_id (po_orgs_rec.org_id);

            FOR po_det_rec IN po_cur (cn_org_id => po_orgs_rec.org_id)
            LOOP
                lv_msg_data       := NULL;
                ln_msg_count      := 0;
                lv_message_data   := NULL;

                --API to update Buyer
                PO_Mass_Update_PO_GRP.Update_Persons (
                    p_update_person      => 'BUYER',
                    p_old_personid       => po_det_rec.old_buyer_id,
                    p_new_personid       => po_det_rec.new_buyer_id,
                    p_document_type      => '',
                    p_document_no_from   => po_det_rec.po_number,
                    p_document_no_to     => po_det_rec.po_number,
                    p_date_from          => '',
                    p_date_to            => '',
                    p_supplier_id        => '',
                    p_include_close_po   => 'NO',  --Do not update closed PO's
                    p_commit_interval    => '',
                    p_msg_data           => lv_msg_data,
                    p_msg_count          => ln_msg_count,
                    p_return_status      => lv_return_status);

                IF    lv_return_status = gv_ret_error
                   OR lv_return_status = gv_ret_unexp_error
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        fnd_msg_pub.get (
                            p_msg_index       => i,
                            p_encoded         => fnd_api.g_false,
                            p_data            => lv_msg_data,
                            p_msg_index_out   => ln_msg_index_out);
                        lv_message_data   := lv_message_data || lv_msg_data;
                    END LOOP;

                    UPDATE xxdo.xxd_po_buyer_upd_po_stg_t stg
                       SET stg.status = 'ERROR', stg.error_message = lv_message_data, stg.last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND stg.po_header_id = po_det_rec.po_header_id
                           AND stg.request_id = gn_conc_request_id;

                    COMMIT;
                ELSE
                    UPDATE xxdo.xxd_po_buyer_upd_po_stg_t stg
                       SET stg.status = 'SUCCESS', stg.last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND stg.po_header_id = po_det_rec.po_header_id
                           AND stg.request_id = gn_conc_request_id;

                    COMMIT;
                END IF;
            END LOOP;                            --po_det_cur cursor end loopd
        END LOOP;                                    --po_orgs cursor end loop

        COMMIT;
        msg ('Updating Buyer on POs - END', 'Y');

        msg ('END - Buyer Update On POs Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END buyer_upd_po;

    PROCEDURE get_items_for_buyer_upd (pn_ret_code   OUT NUMBER,
                                       pv_ret_msg    OUT VARCHAR2)
    IS
        --Local Variables
        lv_proc_name               VARCHAR2 (30) := 'GET_ITEMS_FOR_BUYER_UPD';
        lv_error_msg               VARCHAR2 (2000) := NULL;
        lv_items_cur_stmt          VARCHAR2 (32627) := NULL;
        lv_items_select_clause     VARCHAR2 (10000) := NULL;
        lv_items_from_clause       VARCHAR2 (5000) := NULL;
        lv_items_where_clause      VARCHAR2 (10000) := NULL;
        lv_items_brand_cond        VARCHAR2 (5000) := NULL;
        lv_items_seasons_cond      VARCHAR2 (5000) := NULL;
        lv_items_inv_org_cond      VARCHAR2 (5000) := NULL;
        lv_items_department_cond   VARCHAR2 (5000) := NULL;

        TYPE items_rec_type IS RECORD
        (
            curr_active_season    VARCHAR2 (30),
            brand                 VARCHAR2 (20),
            department            VARCHAR2 (50),
            organization_code     VARCHAR2 (3),
            style                 VARCHAR2 (30),
            color                 VARCHAR2 (30),
            item_size             VARCHAR2 (30),
            sku                   VARCHAR2 (50),
            buyer_name            VARCHAR2 (120),
            new_buyer_name        VARCHAR2 (120),
            old_buyer_id          NUMBER,
            new_buyer_id          NUMBER,
            organization_id       NUMBER,
            inventory_item_id     NUMBER,
            status                VARCHAR2 (30),
            error_message         VARCHAR2 (4000)
        );

        TYPE items_type IS TABLE OF items_rec_type
            INDEX BY PLS_INTEGER;

        items_rec                  items_type;

        TYPE items_cur_typ IS REF CURSOR;

        items_cur                  items_cur_typ;
    BEGIN
        msg ('START - Get Items for Buyer Update Procedure', 'Y');
        lv_items_select_clause   := 'SELECT 
       msi.curr_active_season
      ,msi.brand
      ,msi.department
      --,mp.organization_code
      ,''MST'' organization_code
      ,msi.style_number style
      ,msi.color_code color
      ,msi.item_size
      ,msi.item_number sku
      --,pav_item.agent_name buyer_name
      ,NULL buyer_name
      ,bm.buyer_name new_buyer_name
      ,msi.buyer_id old_buyer_id
      ,bm.buyer_id new_buyer_id
      ,msi.organization_id
      ,msi.inventory_item_id
      ,''NEW'' status
      ,NULL error_message
  ';

        lv_items_from_clause     :=
            'FROM apps.xxd_common_items_v msi,
      (
      SELECT DISTINCT
             flv.attribute1 brand
            ,flv.attribute2 department
            ,pa.agent_id buyer_id
            ,pa.agent_name buyer_name
        FROM apps.fnd_lookup_values flv
            ,apps.po_agents_v pa
       WHERE 1=1
         AND flv.lookup_type = ''DO_BUYER_CODE''
         AND flv.language = ''US''
         AND flv.enabled_flag = ''Y''
         AND SYSDATE BETWEEN NVL(flv.start_date_active, SYSDATE) AND NVL(flv.end_date_active, SYSDATE + 1)
         AND UPPER(flv.description) = UPPER(pa.agent_name)
         AND SYSDATE BETWEEN NVL(pa.start_date_active, SYSDATE) AND NVL(pa.end_date_active, SYSDATE + 1)
       ) bm
--      ,apps.mtl_parameters mp
--      ,apps.po_agents_v pav_item 
 ';

        lv_items_where_clause    :=
            'WHERE 1=1
   AND msi.organization_id = 106 --MST
   AND msi.brand NOT IN (''AHNU'',''TSUBO'',''MOZO'')
   AND msi.brand = bm.brand
   AND msi.department = DECODE(bm.department, ''ALL'', msi.department, bm.department)
   AND NVL(msi.buyer_id, 0) <> bm.buyer_id
--   AND msi.buyer_id = pav_item.agent_id(+)
--   AND msi.organization_id = mp.organization_id
   ';

        --Brand Condition
        IF gv_brand = 'ALL'
        THEN
            lv_items_brand_cond   := 'AND 1=1
            ';
        ELSE
            lv_items_brand_cond   := 'AND msi.brand = ''' || gv_brand || '''
            ';
        END IF;

        --Order Type Exclusion Condition
        IF gv_curr_active_season IS NOT NULL
        THEN
            lv_items_seasons_cond   :=
                   'AND msi.curr_active_season = '''
                || gv_curr_active_season
                || '''
            ';
        END IF;

        --Items Department Condition
        IF gv_department IS NULL OR gv_department = 'ALL'
        THEN
            lv_items_department_cond   := 'AND 1=1
            ';
        ELSE
            lv_items_department_cond   :=
                'AND msi.department = ''' || gv_department || '''
            ';
        END IF;

        --Building the Final Query
        lv_items_cur_stmt        :=
               lv_items_select_clause
            || lv_items_from_clause
            || lv_items_where_clause
            || lv_items_brand_cond
            || lv_items_seasons_cond
            || lv_items_department_cond;
        msg ('-------------------------------------------------');
        msg ('Items Main Query(lv_items_cur_stmt)');
        msg ('-------------------------------------------------');
        msg (lv_items_cur_stmt || ';');
        msg ('-------------------------------------------------');

        --Opening the Items Cursor for the above sql statement(lv_items_cur_stmt)
        BEGIN
            OPEN items_cur FOR lv_items_cur_stmt;

            LOOP
                FETCH items_cur BULK COLLECT INTO items_rec LIMIT 100;

                EXIT WHEN items_rec.COUNT = 0;

                BEGIN
                    --Bulk Insert of Items into staging table
                    FORALL i IN items_rec.FIRST .. items_rec.COUNT
                      SAVE EXCEPTIONS
                        INSERT INTO xxdo.xxd_po_buyer_upd_items_stg_t (
                                        curr_active_season,
                                        brand,
                                        department,
                                        organization_code,
                                        style,
                                        color,
                                        item_size,
                                        sku,
                                        buyer_name,
                                        new_buyer_name,
                                        old_buyer_id,
                                        new_buyer_id,
                                        organization_id,
                                        inventory_item_id,
                                        status,
                                        error_message,
                                        request_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login)
                             VALUES (items_rec (i).curr_active_season, items_rec (i).brand, items_rec (i).department, items_rec (i).organization_code, items_rec (i).style, items_rec (i).color, items_rec (i).item_size, items_rec (i).sku, items_rec (i).buyer_name, items_rec (i).new_buyer_name, items_rec (i).old_buyer_id, items_rec (i).new_buyer_id, items_rec (i).organization_id, items_rec (i).inventory_item_id, items_rec (i).status, items_rec (i).error_message, gn_conc_request_id --request_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , SYSDATE --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , gn_user_id --created_by
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       , SYSDATE --last_update_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , gn_user_id --last_updated_by
                                     , gn_login_id         --last_update_login
                                                  );
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'When Others Exception in Buyer Update in Items Cursor. Error is: '
                            || SUBSTR (SQLERRM, 1, 2000));
                END;

                COMMIT;
            END LOOP;

            CLOSE items_cur;
        END;

        msg ('END - Get Items For Buyer Update Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);

            CLOSE items_cur;
    END get_items_for_buyer_upd;

    --Procedure to Update Buyer on Items
    PROCEDURE buyer_upd_items
    IS
        --Items Cursor
        CURSOR items_cur IS
            SELECT *
              FROM xxdo.xxd_po_buyer_upd_items_stg_t stg
             WHERE     1 = 1
                   AND stg.request_id = gn_conc_request_id
                   AND NVL (stg.status, 'NEW') = 'NEW';

        --Local Variables
        lv_proc_name      VARCHAR2 (30) := 'BUYER_UPD_ITEMS';
        lv_error_msg      VARCHAR2 (2000) := NULL;
        ln_ret_code       NUMBER := NULL;
        lv_ret_msg        VARCHAR2 (2000) := NULL;

        TYPE items_cur_tab_t IS TABLE OF items_cur%ROWTYPE;

        items_array       items_cur_tab_t;
        ln_errors_cnt     NUMBER;
        excp_dml_errors   EXCEPTION;
        PRAGMA EXCEPTION_INIT (excp_dml_errors, -24381);
    BEGIN
        msg ('START - Buyer Update On Items Procedure', 'Y');

        --Calling get_items_for_buyer_upd procedure which identifies the Items to be updated into Items staging table
        msg ('Calling GET_ITEMS_FOR_BUYER_UPD procedure - START', 'Y');
        get_items_for_buyer_upd (pn_ret_code   => ln_ret_code,
                                 pv_ret_msg    => lv_ret_msg);
        msg ('Calling GET_ITEMS_FOR_BUYER_UPD procedure - END', 'Y');
        msg (' ');

        IF ln_ret_code IS NOT NULL AND ln_ret_code <> gn_success
        THEN
            gn_retcode   := ln_ret_code;
            gv_errbuf    := lv_ret_msg;
            RETURN;
        END IF;

        msg ('Updating Buyer on Items - END', 'Y');

        OPEN items_cur;

        LOOP
            FETCH items_cur BULK COLLECT INTO items_array LIMIT 100;

            EXIT WHEN items_array.COUNT = 0;

            BEGIN
                FORALL i IN items_array.FIRST .. items_array.COUNT
                  SAVE EXCEPTIONS
                    UPDATE mtl_system_items_b
                       SET buyer_id   = items_array (i).new_buyer_id
                     WHERE     1 = 1
                           --AND organization_id = items_array(i).organization_id
                           AND inventory_item_id =
                               items_array (i).inventory_item_id;

                --Update status on Staging table
                FORALL i IN items_array.FIRST .. items_array.COUNT
                  SAVE EXCEPTIONS
                    UPDATE xxdo.xxd_po_buyer_upd_items_stg_t stg
                       SET stg.status = 'SUCCESS', stg.last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND request_id = gn_conc_request_id
                           AND NVL (stg.status, 'NEW') = 'NEW'
                           AND inventory_item_id =
                               items_array (i).inventory_item_id;
            EXCEPTION
                WHEN excp_dml_errors
                THEN
                    ROLLBACK;
                    ln_errors_cnt   := SQL%BULK_EXCEPTIONS.COUNT;
                    msg ('Buyer Update Error Count: ' || ln_errors_cnt);

                    --Update status on Staging table
                    FORALL i IN items_array.FIRST .. items_array.COUNT
                      SAVE EXCEPTIONS
                        UPDATE xxdo.xxd_po_buyer_upd_items_stg_t stg
                           SET stg.status = 'ERROR', stg.error_message = 'Error updating Buyer', stg.last_update_date = SYSDATE
                         WHERE     1 = 1
                               AND request_id = gn_conc_request_id
                               AND NVL (stg.status, 'NEW') = 'NEW'
                               AND inventory_item_id =
                                   items_array (i).inventory_item_id;
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    msg (
                           'When Others Exception in Buyer Update in Items Cursor. Error is: '
                        || SUBSTR (SQLERRM, 1, 2000));
            END;

            COMMIT;
        END LOOP;

        CLOSE items_cur;

        COMMIT;
        msg ('Updating Buyer on Items - END', 'Y');

        msg ('END - Buyer Update On Items Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END buyer_upd_items;

    --This is the driving procedure called by Deckers Buyer Update Program
    PROCEDURE buyer_upd_main (pv_errbuf                  OUT NOCOPY VARCHAR2,
                              pn_retcode                 OUT NOCOPY NUMBER,
                              pv_buyer_upd_on         IN            VARCHAR2 --Mandatory
                                                                            ,
                              pv_brand                IN            VARCHAR2 --Mandatory
                                                                            ,
                              pv_curr_active_season   IN            VARCHAR2 --Optional
                                                                            ,
                              pv_department           IN            VARCHAR2 --Optional
                                                                            ,
                              pn_org_id               IN            NUMBER --Optional (For PO's Only)
                                                                          ,
                              pv_buy_season           IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_buy_month            IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_po_date_from         IN            VARCHAR2 --Optional (For PO's Only)
                                                                            ,
                              pv_po_date_to           IN            VARCHAR2 --Optional (For PO's Only)
                                                                            )
    IS
        --Local Variables
        lv_proc_name             VARCHAR2 (30) := 'BUYER_UPDATE_MAIN';
        lv_error_msg             VARCHAR2 (2000) := NULL;
        lv_operating_unit        VARCHAR2 (240) := NULL;
        lv_org_code              VARCHAR2 (3) := NULL;
        lv_resp_operating_unit   VARCHAR2 (240) := NULL;
        ln_so_rec_exists         NUMBER := 0;
        ln_ret_code              NUMBER := 0;
        lv_ret_msg               VARCHAR2 (2000) := NULL;
        ln_incompatible_cnt      NUMBER := 0;
    BEGIN
        msg ('Deckers Buyer Update Program - START', 'Y');
        msg ('Parameters');

        IF pn_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT name
                  INTO lv_operating_unit
                  FROM apps.hr_operating_units
                 WHERE 1 = 1 AND organization_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_operating_unit   := NULL;
            END;
        END IF;

        msg (
            '-------------------------------------------------------------------');

        msg ('Buyer Update On?         : ' || pv_buyer_upd_on);
        msg ('Brand                    : ' || pv_brand);
        msg ('Item Curr Active Season  : ' || pv_curr_active_season);
        msg ('Department               : ' || pv_department);
        msg ('Operating Unit Name      : ' || lv_operating_unit);
        msg ('Operating Unit ID        : ' || pn_org_id);
        msg ('PO Buy Season            : ' || pv_buy_season);
        msg ('PO Buy Month             : ' || pv_buy_month);
        msg ('PO Date From             : ' || pv_po_date_from);
        msg ('PO Date To               : ' || pv_po_date_to);
        msg (
            '-------------------------------------------------------------------');
        msg (' ');
        msg ('Printing Technical Details');
        msg ('Concurrent Request ID    :' || gn_conc_request_id);
        msg ('Concurrent Login ID      :' || gn_conc_login_id);
        msg ('Login ID                 :' || gn_login_id);
        msg (
            '-------------------------------------------------------------------');
        msg (' ');

        --Assigning parameters to Global Variables
        gv_buyer_upd_on         := pv_buyer_upd_on;
        gv_brand                := pv_brand;
        gv_curr_active_season   := pv_curr_active_season;
        gv_department           := pv_department;
        gn_ou_id                := pn_org_id;
        gv_buy_season           := pv_buy_season;
        gv_buy_month            := pv_buy_month;
        gv_po_date_from         := pv_po_date_from;
        gv_po_date_to           := pv_po_date_to;

        --Call procedures based on the Buyer Update On Parameter
        IF gv_buyer_upd_on = 'ITEMS'
        THEN
            IF pv_curr_active_season IS NULL
            THEN
                msg (
                    'Buyer Update on Items is ABORTED as Current Active Seasons parameter is MANDATORY when updating Buyer On Items. Exiting the Program and Completing in WARNING');
                pv_errbuf    :=
                    'Buyer Update on Items is ABORTED as Current Active Seasons parameter is MANDATORY when updating Buyer On Items. Exiting the Program and Completing in WARNING';
                pn_retcode   := gn_warning;
                RETURN;
            END IF;

            SELECT COUNT (1)
              INTO ln_incompatible_cnt
              FROM apps.fnd_concurrent_programs_vl fcp, apps.fnd_concurrent_requests fcr
             WHERE     1 = 1
                   AND fcp.user_concurrent_program_name IN
                           ('PLM Item Hierarchy Update Program – Deckers', 'PLM Item Generator Program-Deckers', 'Item Tax Category Assignment - Deckers')
                   AND fcp.concurrent_program_id = fcr.concurrent_program_id
                   AND fcr.status_code = 'R';

            IF ln_incompatible_cnt > 0
            THEN
                msg (
                    'One or All of the below PLM Programs are running, Please run when these programs are not running. Exiting the Program and Completing in WARNING');
                msg ('PLM Item Hierarchy Update Program – Deckers
                     PLM Item Generator Program-Deckers
                     Item Tax Category Assignment - Deckers');
                pv_errbuf    :=
                    'One or All of the below PLM Programs are running, Please run when these programs are not running. Exiting the Program and Completing in WARNING';
                pn_retcode   := gn_warning;
                RETURN;
            END IF;

            msg ('Calling BUYER_UPD_ITEMS procedure - START', 'Y');
            buyer_upd_items;
            msg ('Calling BUYER_UPD_ITEMS procedure - END', 'Y');
            msg (' ');
        ELSIF gv_buyer_upd_on = 'PURCHASE ORDERS'
        THEN
            msg ('Calling BUYER_UPD_PO procedure - START', 'Y');
            buyer_upd_po;
            msg ('Calling BUYER_UPD_PO procedure - END', 'Y');
            msg (' ');
        END IF;

        --Calling PURGE_DATA procedure to Purge Data from Staging Tables
        msg ('Calling PURGE_DATA procedure - START', 'Y');
        purge_data;
        msg ('Calling PURGE_DATA procedure - END', 'Y');
        msg (' ');
        pn_retcode              := gn_retcode;
        pv_errbuf               := gv_errbuf;
        msg ('pn_retcode:: ' || pn_retcode);
        msg ('pv_errbuf:: ' || pv_errbuf);
        msg ('Deckers Buyer Update Program - END', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
            pv_errbuf    := lv_error_msg;
            pn_retcode   := gn_error;
    END buyer_upd_main;
END XXD_PO_BUYER_UPD_PKG;
/
