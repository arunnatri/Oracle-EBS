--
-- XXDO_PO_APPROVAL_PRG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_APPROVAL_PRG_PKG"
IS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : Purchasing
    --  Project         :
    --  Description     : Package for Approving Purchase Orders
    --  Module          : xxdo_po_approval_pkg
    --  File            : xxdo_po_approval_pkg.pkb
    --  Schema          : APPS
    --  Date            : 03-Sep-2015
    --  Version         : 1.0
    --  Author(s)       : Anil Suddapalli [ Suneratech Consulting]
    --  Purpose         : Package used in different ways
    --                     1. It is scheduled daily to approve POs which are in REQUIRES REAPPROVAL
    --                     2. Used to progress the workflow of POs which are in INPROCESS/PRE-APPROVED status to REQUIRES REAPPROVAL status
    --                     3. Used to approve POs which are CANCELLED, but status is in REQUIRES REAPPROVAL status
    --  dependency      :
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                                   Description
    --  ----------      --------------      -----   --------------------                     ------------------
    --  03-Sep-2015    Anil Suddapalli      1.0                                             Initial Version
    --  13-Nov-2017    Infosys              1.1      CCR0006794                             Considering the POs having Closed Code as CLOSED and requires RE-Approval.


    PROCEDURE main_proc_po_approval (pn_err_code         OUT NUMBER,
                                     pv_err_message      OUT VARCHAR2,
                                     pv_po_type       IN     VARCHAR2,
                                     pn_header_id     IN     NUMBER,
                                     pv_po_status     IN     VARCHAR2)
    IS
        ln_header_id              NUMBER;
        ln_agent_id               NUMBER;
        ln_resp_id                NUMBER;
        ln_resp_appl_id           NUMBER;
        ln_org_id                 NUMBER;
        ln_user_id                NUMBER;
        lv_approved_flag          VARCHAR2 (100);
        lv_authorization_status   VARCHAR2 (400);
        ln_loop_cnt               NUMBER := 0;
        ln_closed_po_loop_cnt     NUMBER := 0;         -- Added for CCR0006794

        CURSOR cur_po_reapproval IS
            SELECT pha.*
              FROM apps.po_headers_all pha, apps.mtl_parameters mp
             WHERE     1 = 1
                   AND NVL (authorization_status, 'N') =
                       'REQUIRES REAPPROVAL'
                   AND NVL (pha.cancel_flag, 'N') <> 'Y'
                   AND NVL (closed_code, 'OPEN') <> 'CLOSED'
                   AND NVL (mp.attribute13, 2) =
                       DECODE (pv_po_type,
                               'Trade', 2,
                               'Non-Trade', 1,
                               mp.attribute13)
                   AND pha.po_header_id =
                       NVL (pn_header_id, pha.po_header_id)
                   AND (SELECT ship_to_organization_id
                          FROM apps.po_line_locations_all plla
                         WHERE     plla.po_header_id = pha.po_header_id
                               AND ROWNUM <= 1) =
                       mp.organization_id;

        CURSOR cur_po_inprocess IS
            SELECT pha.*
              FROM apps.po_headers_all pha, apps.mtl_parameters mp
             WHERE     1 = 1
                   AND NVL (authorization_status, 'N') IN
                           ('IN PROCESS', 'PRE-APPROVED')
                   AND NVL (mp.attribute13, 2) =
                       DECODE (pv_po_type,
                               'Trade', 2,
                               'Non-Trade', 1,
                               mp.attribute13)
                   AND NVL (closed_code, 'OPEN') <> 'CLOSED'
                   AND pha.po_header_id =
                       NVL (pn_header_id, pha.po_header_id)
                   AND (SELECT ship_to_organization_id
                          FROM apps.po_line_locations_all plla
                         WHERE     plla.po_header_id = pha.po_header_id
                               AND ROWNUM <= 1) =
                       mp.organization_id;


        CURSOR cur_po_cancel IS
            SELECT pha.*
              FROM apps.po_headers_all pha, apps.mtl_parameters mp
             WHERE     1 = 1
                   AND NVL (pha.cancel_flag, 'N') = 'Y'
                   AND NVL (authorization_status, 'N') =
                       'REQUIRES REAPPROVAL'
                   AND NVL (mp.attribute13, 2) =
                       DECODE (pv_po_type,
                               'Trade', 2,
                               'Non-Trade', 1,
                               mp.attribute13)
                   AND pha.po_header_id =
                       NVL (pn_header_id, pha.po_header_id)
                   AND (SELECT ship_to_organization_id
                          FROM apps.po_line_locations_all plla
                         WHERE     plla.po_header_id = pha.po_header_id
                               AND ROWNUM <= 1) =
                       mp.organization_id;

        CURSOR cur_po_reapproval_closed         -- Start  Added for CCR0006794
                                        IS
            SELECT pha.*
              FROM apps.po_headers_all pha, apps.mtl_parameters mp
             WHERE     1 = 1
                   AND NVL (authorization_status, 'N') =
                       'REQUIRES REAPPROVAL'
                   AND NVL (pha.cancel_flag, 'N') <> 'Y'
                   AND NVL (closed_code, 'OPEN') = 'CLOSED'
                   AND NVL (mp.attribute13, 2) =
                       DECODE (pv_po_type, 'Trade', 2, 2)
                   AND pha.po_header_id =
                       NVL (pn_header_id, pha.po_header_id)
                   AND (SELECT ship_to_organization_id
                          FROM apps.po_line_locations_all plla
                         WHERE     plla.po_header_id = pha.po_header_id
                               AND ROWNUM <= 1) =
                       mp.organization_id;         -- End Added for CCR0006794
    BEGIN
        apps.fnd_file.put_line (
            fnd_file.LOG,
            '1: ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));

        apps.mo_global.init ('PO');



        apps.fnd_file.put_line (fnd_file.LOG,
                                'po_status parameter: ' || pv_po_status);



        IF (UPPER (pv_po_status) = 'REQUIRES REAPPROVAL')
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                '2: ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));

            FOR rec_pos IN cur_po_reapproval
            LOOP
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'In 1st block: PO Number: ' || rec_pos.segment1);

                apps.mo_global.set_policy_context ('S', rec_pos.org_id);

                ln_loop_cnt   := ln_loop_cnt + 1;

                lv_authorization_status   :=
                    po_approval_script (rec_pos.po_header_id,
                                        rec_pos.agent_id,
                                        rec_pos.segment1);

                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'PO: '
                    || rec_pos.segment1
                    || ' Status at the End: '
                    || po_status (rec_pos.po_header_id));
            END LOOP;

            IF ln_loop_cnt = 0
            THEN
                apps.fnd_file.put_line (fnd_file.LOG, 'No POs processed ');
            END IF;

            ln_closed_po_loop_cnt   := 0;        -- Start Added for CCR0006794

            FOR rec_pos IN cur_po_reapproval_closed
            LOOP
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'In second block: PO Number: ' || rec_pos.segment1);

                apps.mo_global.set_policy_context ('S', rec_pos.org_id);

                ln_closed_po_loop_cnt   := ln_closed_po_loop_cnt + 1;

                lv_authorization_status   :=
                    po_approval_script (rec_pos.po_header_id,
                                        rec_pos.agent_id,
                                        rec_pos.segment1);

                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'PO: '
                    || rec_pos.segment1
                    || ' Status at the End: '
                    || po_status (rec_pos.po_header_id));
            END LOOP;

            IF ln_closed_po_loop_cnt = 0
            THEN
                apps.fnd_file.put_line (fnd_file.LOG, 'No POs processed ');
            END IF;                                -- End Added for CCR0006794
        ELSIF (UPPER (pv_po_status) = 'CANCELLED BUT REQUIRES REAPPROVAL')
        THEN
            FOR rec_pos IN cur_po_cancel
            LOOP
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'In CANCEL Script block: PO Number: ' || rec_pos.segment1);

                apps.mo_global.set_policy_context ('S', rec_pos.org_id);

                ln_loop_cnt   := ln_loop_cnt + 1;

                po_cancel_script (rec_pos.po_header_id, rec_pos.org_id);

                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'After Cancel script done: PO: '
                    || rec_pos.segment1
                    || ' Status: '
                    || po_status (rec_pos.po_header_id));
            END LOOP;


            IF ln_loop_cnt = 0
            THEN
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'PO is Not in Cancelled status, please check the status of the PO ');
            END IF;
        ELSIF (UPPER (pv_po_status) IN ('IN PROCESS', 'PRE-APPROVED'))
        THEN
            FOR rec_pos IN cur_po_inprocess
            LOOP
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'In INPROCESS block: PO Number: ' || rec_pos.segment1);

                apps.mo_global.set_policy_context ('S', rec_pos.org_id);

                ln_loop_cnt   := ln_loop_cnt + 1;

                po_inprocess_script (rec_pos.segment1, rec_pos.org_id, 'N');

                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'After Inprocess script done: PO: '
                    || rec_pos.segment1
                    || ' Status: '
                    || po_status (rec_pos.po_header_id));
            END LOOP;

            IF ln_loop_cnt = 0
            THEN
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'PO Not processed, please check the status of the PO ');
            END IF;
        END IF;

        apps.fnd_file.put_line (
            fnd_file.LOG,
            '5: ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in Main Procedure block: Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END main_proc_po_approval;

    --Below Function is used to approve PO which is in REQUIRES REAPPROVAL status
    FUNCTION po_approval_script (pn_header_id   NUMBER,
                                 pn_agent_id    NUMBER,
                                 pv_po_number   VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_loop_cnt               NUMBER := 0;
        lv_approved_flag          VARCHAR2 (10);
        lv_authorization_status   VARCHAR2 (100);
        v_item_key                VARCHAR2 (100);
        X_ERROR_TEXT              VARCHAR2 (1000);
        X_RET_STAT                VARCHAR2 (1000);
    BEGIN
        apps.fnd_file.put_line (
            fnd_file.LOG,
            '3.0: ' || ': ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));

        SELECT TO_CHAR (pn_header_id) || '-' || TO_CHAR (po_wf_itemkey_s.NEXTVAL)
          INTO v_item_key
          FROM DUAL;

        apps.fnd_file.put_line (fnd_file.LOG, 'Item Key: ' || v_item_key);

        LOOP
            ln_loop_cnt               := ln_loop_cnt + 1;



            BEGIN
                APPS.PO_REQAPPROVAL_INIT1.Start_WF_Process (
                    ItemType                => 'POAPPRV',
                    ItemKey                 => v_item_key,
                    WorkflowProcess         => 'POAPPRV_TOP',
                    ActionOriginatedFrom    => 'PO_FORM',
                    DocumentID              => pn_header_id,
                    DocumentNumber          => pv_po_number,
                    PreparerID              => pn_agent_id,
                    DocumentTypeCode        => 'PO',
                    DocumentSubtype         => 'STANDARD',
                    SubmitterAction         => 'APPROVE'       --''INCOMPLETE'
                                                        ,
                    forwardToID             => NULL        --null-- EMPLOYEEID
                                                   ,
                    forwardFromID           => pn_agent_id,
                    DefaultApprovalPathID   => NULL,
                    Note                    => NULL,
                    printFlag               => 'N');
            --                                    apps.do_po_purch_order_utils_pvt.approve_po(p_po_header_id => pn_header_id,
            --                                                                                x_error_text => x_error_text,
            --                                                                                x_ret_stat => x_ret_stat);
            --
            --                                                    apps.fnd_file.put_line(fnd_file.LOG,'Error text:'||x_error_text);
            --                                                    apps.fnd_file.put_line(fnd_file.LOG,'Error stat:'||x_ret_stat);


            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception in PO Approval Script, In API call: Error Code: '
                        || SQLCODE
                        || 'Error Message: '
                        || SUBSTR (SQLERRM, 1, 900));
            END;

            apps.fnd_file.put_line (
                fnd_file.LOG,
                   '3: '
                || ln_loop_cnt
                || ': '
                || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS'));

            COMMIT;

            lv_authorization_status   := po_status (pn_header_id);

            EXIT WHEN lv_authorization_status = 'APPROVED' OR ln_loop_cnt = 3;
        END LOOP;

        apps.fnd_file.put_line (fnd_file.LOG, 'Loop Count: ' || ln_loop_cnt);

        RETURN lv_authorization_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;

            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Approval Script: Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END po_approval_script;

    --Below Procedure is used to progress the workflow of POs which are in INPROCESS/PRE-APPROVED status to REQUIRES REAPPROVAL status
    PROCEDURE po_inprocess_script (pv_po_number IN VARCHAR2, pn_org_id IN NUMBER, pv_delete_act_hist IN VARCHAR2 DEFAULT 'N')
    IS
        /*REM dbdrv: none
                /*=======================================================================+
              |  Copyright (c) 2009 Oracle Corporation Redwood Shores, California, USA|
              |                            All rights reserved.                       |
              +=======================================================================*/

        /* $Header: poxrespo.sql 120.0.12010000.4 2010/06/09 00:12:31 vrecharl noship $ */
        --SET SERVEROUTPUT ON
        --SET VERIFY OFF;


        /* PLEASE READ NOTE 390023.1 CAREFULLY BEFORE EXECUTING THIS SCRIPT.

         This script will:
        * reset the document to incomplete/requires reapproval status.
        * delete/update action history as desired (refere note 390023.1 for more details).
        * abort all the related workflows

        * If there is a distribution with wrong encumbrance amount related to this PO,
        * it will: skip the reset action on the document.
        */

        --set serveroutput on size 100000
        --prompt
        --prompt
        --accept sql_po_number prompt 'Please enter the PO number to reset : ';
        --accept sql_org_id default NULL prompt 'Please enter the organization id to which the PO belongs (Default NULL) : ';
        --accept delete_act_hist prompt 'Do you want to delete the action history since the last approval ? (Y/N) ';
        --prompt


        --DECLARE

        /* select only the POs which are in preapproved, in process state and are not finally closed
           cancelled */

        CURSOR potoreset (po_number VARCHAR2, x_org_id NUMBER)
        IS
            SELECT wf_item_type, wf_item_key, po_header_id,
                   segment1, revision_num, type_lookup_code,
                   approved_date
              FROM po_headers_all
             WHERE     segment1 = po_number
                   AND NVL (org_id, -99) = NVL (x_org_id, -99)
                   -- bug 5015493: Need to allow reset of blankets and PPOs also.
                   -- and type_lookup_code = 'STANDARD'
                   AND authorization_status IN ('IN PROCESS', 'PRE-APPROVED')
                   AND NVL (cancel_flag, 'N') = 'N'
                   AND NVL (closed_code, 'OPEN') <> 'FINALLY_CLOSED';

        /* select the max sequence number with NULL action code */

        CURSOR maxseq (id        NUMBER,
                       subtype   po_action_history.object_sub_type_code%TYPE)
        IS
            SELECT NVL (MAX (sequence_num), 0)
              FROM po_action_history
             WHERE     object_type_code IN ('PO', 'PA')
                   AND object_sub_type_code = subtype
                   AND object_id = id
                   AND action_code IS NULL;

        /* select the max sequence number with submit action */

        CURSOR poaction (
            id        NUMBER,
            subtype   po_action_history.object_sub_type_code%TYPE)
        IS
            SELECT NVL (MAX (sequence_num), 0)
              FROM po_action_history
             WHERE     object_type_code IN ('PO', 'PA')
                   AND object_sub_type_code = subtype
                   AND object_id = id
                   AND action_code = 'SUBMIT';

        CURSOR wfstoabort (st_item_type VARCHAR2, st_item_key VARCHAR2)
        IS
                SELECT LEVEL, item_type, item_key,
                       end_date
                  FROM wf_items
            START WITH item_type = st_item_type AND item_key = st_item_key
            CONNECT BY     PRIOR item_type = parent_item_type
                       AND PRIOR item_key = parent_item_key
              ORDER BY LEVEL DESC;

        wf_rec                     wfstoabort%ROWTYPE;

        submitseq                  po_action_history.sequence_num%TYPE;
        nullseq                    po_action_history.sequence_num%TYPE;

        x_organization_id          NUMBER;
        x_po_number                VARCHAR2 (20);
        po_enc_flag                VARCHAR2 (1);
        x_open_notif_exist         VARCHAR2 (1);
        pos                        potoreset%ROWTYPE;

        x_progress                 VARCHAR2 (500);
        x_cont                     VARCHAR2 (10);
        x_active_wf_exists         VARCHAR2 (1);
        l_delete_act_hist          VARCHAR2 (1);
        l_change_req_exists        VARCHAR2 (1);
        l_res_seq                  po_action_history.sequence_num%TYPE;
        l_sub_res_seq              po_action_history.sequence_num%TYPE;
        l_res_act                  po_action_history.action_code%TYPE;
        l_del_res_hist             VARCHAR2 (1);


        /* For encumbrance actions */

        NAME_ALREADY_USED          EXCEPTION;
        PRAGMA EXCEPTION_INIT (NAME_ALREADY_USED, -955);
        X_STMT                     VARCHAR2 (2000);
        disallow_script            VARCHAR2 (1);

        TYPE enc_tbl_number IS TABLE OF NUMBER;

        TYPE enc_tbl_flag IS TABLE OF VARCHAR2 (1);

        l_dist_id                  enc_tbl_number;
        l_enc_flag                 enc_tbl_flag;
        l_enc_amount               enc_tbl_number;
        l_gl_amount                enc_tbl_number;
        l_manual_cand              enc_tbl_flag;
        l_req_dist_id              enc_tbl_number;
        l_req_enc_flag             enc_tbl_flag;
        l_req_enc_amount           enc_tbl_number;
        l_req_gl_amount            enc_tbl_number;
        l_req_qty_bill_del         enc_tbl_number;
        l_rate_table               enc_tbl_number;
        l_price_table              enc_tbl_number;
        l_qty_ordered_table        enc_tbl_number;
        l_req_price_table          enc_tbl_number;
        l_req_encumbrance_flag     VARCHAR2 (1);
        l_purch_encumbrance_flag   VARCHAR2 (1);
        l_remainder_qty            NUMBER;
        l_bill_del_amount          NUMBER;
        l_req_bill_del_amount      NUMBER;
        l_qty_bill_del             NUMBER;
        l_timestamp                DATE;
        l_eff_quantity             NUMBER;
        l_rate                     NUMBER;
        l_price                    NUMBER;
        l_ordered_quantity         NUMBER;
        l_tax                      NUMBER;
        l_amount                   NUMBER;
        l_precision                fnd_currencies.precision%TYPE;
        l_min_acc_unit             fnd_currencies.minimum_accountable_unit%TYPE;
        l_approved_flag            po_line_locations_all.approved_flag%TYPE;
        i                          NUMBER;
        j                          NUMBER;
        k                          NUMBER;
    BEGIN
        SELECT pv_delete_act_hist INTO l_delete_act_hist FROM DUAL;

        SELECT pn_org_id INTO x_organization_id FROM DUAL;

        SELECT pv_po_number INTO x_po_number FROM DUAL;


        x_progress        := '010: start';

        BEGIN
            SELECT 'Y'
              INTO x_open_notif_exist
              FROM DUAL
             WHERE EXISTS
                       (SELECT 'open notifications'
                          FROM wf_item_activity_statuses wias, wf_notifications wfn, po_headers_all poh
                         WHERE     wias.notification_id IS NOT NULL
                               AND wias.notification_id = wfn.GROUP_ID
                               AND wfn.status = 'OPEN'
                               AND wias.item_type = 'POAPPRV'
                               AND wias.item_key = poh.wf_item_key
                               AND NVL (poh.org_id, -99) =
                                   NVL (x_organization_id, -99)
                               AND poh.segment1 = x_po_number
                               AND poh.authorization_status IN
                                       ('IN PROCESS', 'PRE-APPROVED'));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
        END;

        x_progress        := '020: selected open notif';

        IF (x_open_notif_exist = 'Y')
        THEN
            DBMS_OUTPUT.put_line ('  ');
            DBMS_OUTPUT.put_line (
                'An Open notification exists for this document, you may want to use the notification to process this document. Do not commit if you wish to use the notification');
        END IF;

        BEGIN
            SELECT 'Y'
              INTO l_change_req_exists
              FROM DUAL
             WHERE EXISTS
                       (SELECT 'po with change request'
                          FROM po_headers_all h
                         WHERE     h.segment1 = x_po_number
                               AND NVL (h.org_id, -99) =
                                   NVL (x_organization_id, -99)
                               AND h.change_requested_by IN
                                       ('REQUESTER', 'SUPPLIER'));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
        END;

        IF (l_change_req_exists = 'Y')
        THEN
            DBMS_OUTPUT.put_line ('  ');
            DBMS_OUTPUT.put_line (
                'ATTENTION !!! There is an open change request against this PO. You should respond to the notification for the same.');
            RETURN;
            DBMS_OUTPUT.put_line (
                'If you are running this script unaware of the change request, Please ROLLBACK');
        END IF;

        OPEN potoreset (x_po_number, x_organization_id);

        FETCH potoreset INTO pos;

        IF potoreset%NOTFOUND
        THEN
            DBMS_OUTPUT.put_line (
                   'No PO with PO Number '
                || x_po_number
                || ' exists in org '
                || TO_CHAR (x_organization_id)
                || ' which requires to be reset');
            RETURN;
        END IF;

        CLOSE potoreset;

        x_progress        := '030 checking enc action ';

        -- If there exists any open shipment with one of its distributions reserved, then
        -- 1. For a Standard PO, check whether the present Encumbrance amount on the distribution
        --    is correct or not. If its not correct do not reset the document.
        -- 2. For a Blanket PO (irrespective of Encumbrance enabled or not), reset the document.
        -- 3. For a Planned PO, always do not reset the document.
        disallow_script   := 'N';

        BEGIN
            SELECT 'Y'
              INTO disallow_script
              FROM DUAL
             WHERE EXISTS
                       (SELECT 'Wrong Encumbrance Amount'
                          FROM po_headers_all h, po_lines_all l, po_line_locations_all s,
                               po_distributions_all d
                         WHERE     s.line_location_id = d.line_location_id
                               AND l.po_line_id = s.po_line_id
                               AND h.po_header_id = d.po_header_id
                               AND d.po_header_id = pos.po_header_id
                               AND l.matching_basis = 'QUANTITY'
                               AND NVL (d.encumbered_flag, 'N') = 'Y'
                               AND NVL (s.cancel_flag, 'N') = 'N'
                               AND NVL (s.closed_code, 'OPEN') <>
                                   'FINALLY CLOSED'
                               AND NVL (d.prevent_encumbrance_flag, 'N') =
                                   'N'
                               AND d.budget_account_id IS NOT NULL
                               AND NVL (s.shipment_type, 'BLANKET') =
                                   'STANDARD'
                               AND (ROUND (NVL (d.encumbered_amount, 0), 2) <> ROUND ((s.price_override * d.quantity_ordered * NVL (d.rate, 1) + NVL (d.nonrecoverable_tax, 0) * NVL (d.rate, 1)), 2))
                        UNION
                        SELECT 'Wrong Encumbrance Amount'
                          FROM po_headers_all h, po_lines_all l, po_line_locations_all s,
                               po_distributions_all d
                         WHERE     s.line_location_id = d.line_location_id
                               AND l.po_line_id = s.po_line_id
                               AND h.po_header_id = d.po_header_id
                               AND d.po_header_id = pos.po_header_id
                               AND l.matching_basis = 'AMOUNT'
                               AND NVL (d.encumbered_flag, 'N') = 'Y'
                               AND NVL (s.cancel_flag, 'N') = 'N'
                               AND NVL (s.closed_code, 'OPEN') <>
                                   'FINALLY CLOSED'
                               AND NVL (d.prevent_encumbrance_flag, 'N') =
                                   'N'
                               AND d.budget_account_id IS NOT NULL
                               AND NVL (s.shipment_type, 'BLANKET') =
                                   'STANDARD'
                               AND (ROUND (NVL (d.encumbered_amount, 0), 2) <> ROUND ((d.amount_ordered + NVL (d.nonrecoverable_tax, 0)) * NVL (d.rate, 1), 2))
                        UNION
                        SELECT 'Wrong Encumbrance Amount'
                          FROM po_headers_all h, po_lines_all l, po_line_locations_all s,
                               po_distributions_all d
                         WHERE     s.line_location_id = d.line_location_id
                               AND l.po_line_id = s.po_line_id
                               AND h.po_header_id = d.po_header_id
                               AND d.po_header_id = pos.po_header_id
                               AND NVL (d.encumbered_flag, 'N') = 'Y'
                               AND NVL (d.prevent_encumbrance_flag, 'N') =
                                   'N'
                               AND d.budget_account_id IS NOT NULL
                               AND NVL (s.shipment_type, 'BLANKET') =
                                   'PLANNED');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
        END;

        IF disallow_script = 'Y'
        THEN
            DBMS_OUTPUT.put_line (
                'This PO has at least one distribution with wrong Encumbrance amount.');
            DBMS_OUTPUT.put_line ('Hence this PO can not be reset.');
            RETURN;
        END IF;

        DBMS_OUTPUT.put_line (
            'Processing ' || pos.type_lookup_code || ' PO Number: ' || pos.segment1);
        DBMS_OUTPUT.put_line ('......................................');

        BEGIN
            SELECT 'Y'
              INTO x_active_wf_exists
              FROM wf_items wfi
             WHERE     wfi.item_type = pos.wf_item_type
                   AND wfi.item_key = pos.wf_item_key
                   AND wfi.end_date IS NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_active_wf_exists   := 'N';
        END;

        IF (x_active_wf_exists = 'Y')
        THEN
            DBMS_OUTPUT.put_line ('Aborting Workflow...');

            OPEN wfstoabort (pos.wf_item_type, pos.wf_item_key);

            LOOP
                FETCH wfstoabort INTO wf_rec;

                IF wfstoabort%NOTFOUND
                THEN
                    CLOSE wfstoabort;

                    EXIT;
                END IF;

                IF (wf_rec.end_date IS NULL)
                THEN
                    BEGIN
                        WF_Engine.AbortProcess (wf_rec.item_type,
                                                wf_rec.item_key);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            DBMS_OUTPUT.put_line (
                                   ' workflow not aborted :'
                                || wf_rec.item_type
                                || '-'
                                || wf_rec.item_key);
                    END;
                END IF;
            END LOOP;
        END IF;

        DBMS_OUTPUT.put_line ('Updating PO Status..');

        UPDATE po_headers_all
           SET authorization_status = DECODE (pos.approved_date, NULL, 'INCOMPLETE', 'REQUIRES REAPPROVAL'), wf_item_type = NULL, wf_item_key = NULL,
               approved_flag = DECODE (pos.approved_date, NULL, 'N', 'R')
         WHERE po_header_id = pos.po_header_id;

        OPEN maxseq (pos.po_header_id, pos.type_lookup_code);

        FETCH maxseq INTO nullseq;

        CLOSE maxseq;

        OPEN poaction (pos.po_header_id, pos.type_lookup_code);

        FETCH poaction INTO submitseq;

        CLOSE poaction;

        IF nullseq > submitseq
        THEN
            IF NVL (l_delete_act_hist, 'N') = 'N'
            THEN
                UPDATE po_action_history
                   SET action_code = 'NO ACTION', action_date = TRUNC (SYSDATE), note = 'updated by reset script on ' || TO_CHAR (TRUNC (SYSDATE))
                 WHERE     object_id = pos.po_header_id
                       AND object_type_code =
                           DECODE (pos.type_lookup_code,
                                   'STANDARD', 'PO',
                                   'PLANNED', 'PO', --future plan to enhance for planned PO
                                   'PA')
                       AND object_sub_type_code = pos.type_lookup_code
                       AND sequence_num = nullseq
                       AND action_code IS NULL;
            ELSE
                DELETE po_action_history
                 WHERE     object_id = pos.po_header_id
                       AND object_type_code =
                           DECODE (pos.type_lookup_code,
                                   'STANDARD', 'PO',
                                   'PLANNED', 'PO', --future plan to enhance for planned PO
                                   'PA')
                       AND object_sub_type_code = pos.type_lookup_code
                       AND sequence_num >= submitseq
                       AND sequence_num <= nullseq;
            END IF;
        END IF;

        DBMS_OUTPUT.put_line ('Done Approval Processing.');

        SELECT NVL (purch_encumbrance_flag, 'N')
          INTO l_purch_encumbrance_flag
          FROM financials_system_params_all fspa
         WHERE NVL (fspa.org_id, -99) = NVL (x_organization_id, -99);

        IF    (l_purch_encumbrance_flag = 'N')
           -- bug 5015493 : Need to allow reset for blankets also
           OR (pos.type_lookup_code = 'BLANKET')
        THEN
            IF (pos.type_lookup_code = 'BLANKET')
            THEN
                DBMS_OUTPUT.put_line ('document reset successfully');
                DBMS_OUTPUT.put_line (
                    'If you are using Blanket encumbrance, Please ROLLBACK, else COMMIT');
            ELSE
                DBMS_OUTPUT.put_line ('document reset successfully');
                DBMS_OUTPUT.put_line ('please COMMIT data');
            END IF;

            RETURN;
        END IF;

        -- reserve action history stuff
        -- check the action history and delete any reserve to submit actions if all the distributions
        -- are now unencumbered, this should happen only if we are deleting the action history

        IF l_delete_act_hist = 'Y'
        THEN
            -- first get the last sequence and action code from action history
            BEGIN
                SELECT sequence_num, action_code
                  INTO l_res_seq, l_res_act
                  FROM po_action_history pah
                 WHERE     pah.object_id = pos.po_header_id
                       AND pah.object_type_code =
                           DECODE (pos.type_lookup_code,
                                   'STANDARD', 'PO',
                                   'PLANNED', 'PO', --future plan to enhance for planned PO
                                   'PA')
                       AND pah.object_sub_type_code = pos.type_lookup_code
                       AND sequence_num IN
                               (SELECT MAX (sequence_num)
                                  FROM po_action_history pah1
                                 WHERE     pah1.object_id = pah.object_id
                                       AND pah1.object_type_code =
                                           pah.object_type_code
                                       AND pah1.object_sub_type_code =
                                           pah.object_sub_type_code);
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    DBMS_OUTPUT.put_line (
                        'action history needs to be corrected separately ');
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            -- now if the last action is reserve get the last submit action sequence

            IF (l_res_act = 'RESERVE')
            THEN
                BEGIN
                    SELECT MAX (sequence_num)
                      INTO l_sub_res_seq
                      FROM po_action_history pah
                     WHERE     action_code = 'SUBMIT'
                           AND pah.object_id = pos.po_header_id
                           AND pah.object_type_code =
                               DECODE (pos.type_lookup_code,
                                       'STANDARD', 'PO',
                                       'PLANNED', 'PO', --future plan to enhance for planned PO
                                       'PA')
                           AND pah.object_sub_type_code =
                               pos.type_lookup_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                END;

                -- check if we need to delete the action history, ie. if all the distbributions
                -- are unreserved

                IF ((l_sub_res_seq IS NOT NULL) AND (l_res_seq > l_sub_res_seq))
                THEN
                    BEGIN
                        SELECT 'Y'
                          INTO l_del_res_hist
                          FROM DUAL
                         WHERE NOT EXISTS
                                   (SELECT 'encumbered dist'
                                      FROM po_distributions_all pod
                                     WHERE     pod.po_header_id =
                                               pos.po_header_id
                                           AND NVL (pod.encumbered_flag, 'N') =
                                               'Y'
                                           AND NVL (
                                                   pod.prevent_encumbrance_flag,
                                                   'N') =
                                               'N');
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_del_res_hist   := 'N';
                    END;

                    IF l_del_res_hist = 'Y'
                    THEN
                        DBMS_OUTPUT.put_line (
                            'deleting reservation action history ... ');

                        DELETE po_action_history pah
                         WHERE     pah.object_id = pos.po_header_id
                               AND pah.object_type_code =
                                   DECODE (pos.type_lookup_code,
                                           'STANDARD', 'PO',
                                           'PLANNED', 'PO', --future plan to enhance for planned PO
                                           'PA')
                               AND pah.object_sub_type_code =
                                   pos.type_lookup_code
                               AND sequence_num >= l_sub_res_seq
                               AND sequence_num <= l_res_seq;
                    END IF;
                END IF;                           -- l_res_seq > l_sub_res_seq
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Inprocess Script '
                || SQLERRM
                || ' rolling back'
                || x_progress);
            ROLLBACK;
    END po_inprocess_script;

    --Below Procedure is used to approve POs which are CANCELLED, but status is in REQUIRES REAPPROVAL status

    PROCEDURE po_cancel_script (pn_header_id IN NUMBER, pn_org_id IN NUMBER)
    IS
        l_conterms_exist_flag   PO.PO_HEADERS_ALL.conterms_exist_flag%TYPE;
        l_auth_status           VARCHAR2 (30);
        l_revision_num          NUMBER;
        l_request_id            NUMBER := 0;
        l_doc_type              VARCHAR2 (30);
        l_doc_subtype           VARCHAR2 (30);
        l_comm_doc_type         VARCHAR2 (30);
        l_document_id           NUMBER;
        l_agent_id              NUMBER;
        l_printflag             VARCHAR2 (1) := 'N';
        l_faxflag               VARCHAR2 (1) := 'N';
        l_faxnum                VARCHAR2 (30);
        l_emailflag             VARCHAR2 (1) := 'N';
        l_emailaddress          PO_VENDOR_SITES.email_address%TYPE;
        l_default_method        PO_VENDOR_SITES.supplier_notif_method%TYPE;
        l_user_id               po_lines.last_updated_by%TYPE := -1;
        l_login_id              po_lines.last_update_login%TYPE := -1;
        x_return_status         VARCHAR2 (1);
        x_msg_data              VARCHAR2 (2000);
        l_doc_num               VARCHAR2 (30);
        l_approval_path_id      NUMBER;
        l_progress              NUMBER;
    BEGIN
        l_document_id   := pn_header_id;

        --  fnd_global.apps_initialize(
        --     user_id => ,
        --     resp_id => ,
        --     resp_appl_id => );

        po_moac_utils_pvt.set_org_context (pn_org_id);

        -- Set the FND profile option values.
        FND_PROFILE.put ('AFLOG_ENABLED', 'Y');
        FND_PROFILE.put ('AFLOG_MODULE', '%');
        FND_PROFILE.put ('AFLOG_LEVEL', TO_CHAR (1));
        FND_PROFILE.put ('AFLOG_FILENAME', '');

        -- Refresh the FND cache.
        FND_LOG_REPOSITORY.init ();

        --Get User ID and Login ID
        l_user_id       := FND_GLOBAL.USER_ID;
        l_login_id      := FND_GLOBAL.LOGIN_ID;

        BEGIN
            SELECT NVL (conterms_exist_flag, 'N'), revision_num, DECODE (type_lookup_code,  'BLANKET', 'PA',  'CONTRACT', 'PA',  'PO'),
                   type_lookup_code, AGENT_ID
              INTO l_conterms_exist_flag, l_revision_num, l_doc_type, l_doc_subtype,
                                        l_agent_id
              FROM po_headers_all
             WHERE po_header_id = l_document_id;

            l_comm_doc_type   := l_doc_subtype;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                SELECT NVL (poh.conterms_exist_flag, 'N'), por.revision_num, 'RELEASE',
                       poh.type_lookup_code, por.AGENT_ID
                  INTO l_conterms_exist_flag, l_revision_num, l_doc_type, l_doc_subtype,
                                            l_agent_id
                  FROM po_releases_all por, po_headers_all poh
                 WHERE     po_release_id = l_document_id
                       AND poh.po_header_id = por.po_header_id;

                l_comm_doc_type   := l_doc_type;
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                       'IN EXCEPTION sqlcode: '
                    || SQLCODE
                    || 'sqlerrm: '
                    || SQLERRM);
        END;


        SELECT podt.default_approval_path_id
          INTO l_approval_path_id
          FROM po_document_types podt
         WHERE     podt.document_type_code = l_doc_type
               AND podt.document_subtype = l_doc_subtype;

        SELECT MAX (LOG_SEQUENCE) INTO l_progress FROM FND_LOG_MESSAGES;

        DBMS_OUTPUT.put_line (
            'Sequence no before approving : ' || l_progress);

        PO_DOCUMENT_ACTION_PVT.do_approve (p_document_id => l_document_id, p_document_type => l_doc_type, p_document_subtype => l_doc_subtype, p_note => NULL, p_approval_path_id => l_approval_path_id, x_return_status => x_return_status
                                           , x_exception_msg => x_msg_data);

        SELECT MAX (LOG_SEQUENCE) INTO l_progress FROM FND_LOG_MESSAGES;

        DBMS_OUTPUT.put_line ('Sequence no after approving : ' || l_progress);


        IF x_return_status = 'S'
        THEN
            DBMS_OUTPUT.put_line ('Getting default communication method');

            -- Communicate    to the Supplier
            PO_VENDOR_SITES_SV.get_transmission_defaults (
                p_document_id          => l_document_id,
                p_document_type        => l_doc_type,
                p_document_subtype     => l_doc_subtype,
                p_preparer_id          => l_agent_id,
                x_default_method       => l_default_method,
                x_email_address        => l_emailaddress,
                x_fax_number           => l_faxnum,
                x_document_num         => l_doc_num,
                p_retrieve_only_flag   => 'Y');

            IF (l_default_method = 'EMAIL') AND (l_emailaddress IS NOT NULL)
            THEN
                l_faxnum   := NULL;
            ELSIF (l_default_method = 'FAX') AND (l_faxnum IS NOT NULL)
            THEN
                l_emailaddress   := NULL;
            ELSIF (l_default_method = 'PRINT')
            THEN
                l_emailaddress   := NULL;
                l_faxnum         := NULL;
            ELSE
                l_default_method   := 'PRINT';
                l_emailaddress     := NULL;
                l_faxnum           := NULL;
            END IF;

            DBMS_OUTPUT.put_line ('l_default_method : ' || l_default_method);


            Po_Communication_PVT.communicate (p_authorization_status => PO_DOCUMENT_ACTION_PVT.g_doc_status_APPROVED, p_with_terms => l_conterms_exist_flag, p_language_code => FND_GLOBAL.CURRENT_LANGUAGE, p_mode => l_default_method, p_document_id => l_document_id, p_revision_number => l_revision_num, p_document_type => l_comm_doc_type, p_fax_number => l_faxnum, p_email_address => l_emailaddress
                                              , p_request_id => l_request_id);

            SELECT MAX (LOG_SEQUENCE) INTO l_progress FROM FND_LOG_MESSAGES;

            DBMS_OUTPUT.put_line (
                'Sequence no after communicate : ' || l_progress);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'IN EXCEPTION sqlcode: ' || SQLCODE || 'sqlerrm: ' || SQLERRM);

            SELECT MAX (LOG_SEQUENCE) INTO l_progress FROM FND_LOG_MESSAGES;

            DBMS_OUTPUT.put_line (
                'Sequence no in exception : ' || l_progress);
    END po_cancel_script;

    --Below Functions is used to check the status of PO
    FUNCTION po_status (pn_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_authorization_status   VARCHAR2 (100);
    BEGIN
        SELECT authorization_status
          INTO lv_authorization_status
          FROM apps.po_headers_all pha
         WHERE 1 = 1 AND pha.po_header_id = pn_header_id;

        RETURN lv_authorization_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Status Function: Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END po_status;
END xxdo_po_approval_prg_pkg;
/
