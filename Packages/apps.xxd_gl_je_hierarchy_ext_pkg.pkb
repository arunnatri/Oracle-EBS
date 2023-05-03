--
-- XXD_GL_JE_HIERARCHY_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_JE_HIERARCHY_EXT_PKG"
AS
    /*************************************************************************************
   * Package         : XXD_GL_JE_HIERARCHY_EXT_PKG
   * Description     : This package is used for GL Journal Entry Hierarchy Report
   * Notes           :
   * Modification    :
   *-------------------------------------------------------------------------------------
   * Date         Version#      Name                       Description
   *-------------------------------------------------------------------------------------
   * 02-DEC-2021  1.0           Aravind Kannuri            Initial Version for CCR0009551
   *
   ***************************************************************************************/
    --Datatemplate xml main
    FUNCTION main
        RETURN BOOLEAN
    IS
    BEGIN
        insert_staging;

        insert_supervisor_hier;

        validate_duplication;

        recheck_mgr_resp_dt;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in MAIN: ' || SQLERRM);
            RETURN FALSE;
    END main;

    --Insert Subordinates to Staging
    PROCEDURE insert_staging
    IS
        CURSOR c_sub_dtls IS
              SELECT subordinate, sub subordinate_id
                --xxd_gl_je_hierarchy_ext_pkg.get_sup_list(sub) manager
                FROM (SELECT sub,
                             sup,
                             (SELECT user_name
                                FROM fnd_user
                               WHERE user_id = sub) subordinate,
                             (SELECT user_name
                                FROM fnd_user
                               WHERE user_id = sup) manager
                        FROM (SELECT sup.flex_value sup, sub.flex_value sub
                                FROM apps.fnd_flex_values_vl sub,
                                     apps.fnd_flex_value_sets subv,
                                     apps.fnd_flex_values_vl sup,
                                     apps.fnd_flex_value_sets supv,
                                     (  SELECT furg.user_id
                                          FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                                         WHERE     furg.responsibility_id =
                                                   frv.responsibility_id
                                               AND furg.user_id = fu.user_id
                                               AND UPPER (
                                                       frv.responsibility_name) LIKE
                                                       '%DECKERS%G%LEDGER USER%'
                                               AND NVL (furg.start_date, SYSDATE) <
                                                   NVL (
                                                       get_end_date_fy (
                                                           p_cut_off_date,
                                                           furg.end_date),
                                                       NVL (furg.start_date,
                                                            SYSDATE))
                                               AND NVL (
                                                       fnd_date.canonical_to_date (
                                                           p_cut_off_date),
                                                       SYSDATE) BETWEEN NVL (
                                                                            furg.start_date,
                                                                            SYSDATE)
                                                                    AND NVL (
                                                                            get_end_date_fy (
                                                                                p_cut_off_date,
                                                                                furg.end_date),
                                                                            NVL (
                                                                                  furg.start_date
                                                                                - 1,
                                                                                  SYSDATE
                                                                                - 1))
                                               AND NVL (fu.start_date, SYSDATE) <
                                                   NVL (
                                                       get_end_date_fy (
                                                           p_cut_off_date,
                                                           fu.end_date),
                                                       NVL (fu.start_date,
                                                            SYSDATE))
                                               AND NVL (
                                                       fnd_date.canonical_to_date (
                                                           p_cut_off_date),
                                                       SYSDATE) BETWEEN NVL (
                                                                            fu.start_date,
                                                                            SYSDATE)
                                                                    AND NVL (
                                                                            get_end_date_fy (
                                                                                p_cut_off_date,
                                                                                fu.end_date),
                                                                            NVL (
                                                                                  fu.start_date
                                                                                - 1,
                                                                                  SYSDATE
                                                                                - 1))
                                      GROUP BY furg.user_id
                                      ORDER BY furg.user_id) res,
                                     (  SELECT furg.user_id
                                          FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                                         WHERE     furg.responsibility_id =
                                                   frv.responsibility_id
                                               AND furg.user_id = fu.user_id
                                               AND UPPER (
                                                       frv.responsibility_name) LIKE
                                                       '%DECKERS%G%LEDGER MANAGER%'
                                               AND NVL (furg.start_date, SYSDATE) <
                                                   NVL (
                                                       get_end_date_fy (
                                                           p_cut_off_date,
                                                           furg.end_date),
                                                       NVL (furg.start_date,
                                                            SYSDATE))
                                               AND NVL (
                                                       fnd_date.canonical_to_date (
                                                           p_cut_off_date),
                                                       SYSDATE) BETWEEN NVL (
                                                                            furg.start_date,
                                                                            SYSDATE)
                                                                    AND NVL (
                                                                            get_end_date_fy (
                                                                                p_cut_off_date,
                                                                                furg.end_date),
                                                                            NVL (
                                                                                  furg.start_date
                                                                                - 1,
                                                                                  SYSDATE
                                                                                - 1))
                                               AND NVL (fu.start_date, SYSDATE) <
                                                   NVL (
                                                       get_end_date_fy (
                                                           p_cut_off_date,
                                                           fu.end_date),
                                                       NVL (fu.start_date,
                                                            SYSDATE))
                                               AND NVL (
                                                       fnd_date.canonical_to_date (
                                                           p_cut_off_date),
                                                       SYSDATE) BETWEEN NVL (
                                                                            fu.start_date,
                                                                            SYSDATE)
                                                                    AND NVL (
                                                                            get_end_date_fy (
                                                                                p_cut_off_date,
                                                                                fu.end_date),
                                                                            NVL (
                                                                                  fu.start_date
                                                                                - 1,
                                                                                  SYSDATE
                                                                                - 1))
                                      GROUP BY furg.user_id
                                      ORDER BY furg.user_id) mgr
                               WHERE     sub.flex_value_set_id =
                                         subv.flex_value_set_id
                                     AND sub.enabled_flag = 'Y'
                                     AND sub.parent_flex_value_low <>
                                         sub.flex_value
                                     AND sup.flex_value_set_id =
                                         supv.flex_value_set_id
                                     AND sup.flex_value =
                                         sub.parent_flex_value_low
                                     AND sup.enabled_flag = 'Y'
                                     AND sup.parent_flex_value_low IS NULL
                                     AND subv.flex_value_set_name =
                                         'DO_SUBORDINATES'
                                     AND supv.flex_value_set_name LIKE
                                             'DO_SUPERVISOR'
                                     AND res.user_id = sub.flex_value
                                     AND mgr.user_id = sup.flex_value) tbl)
            GROUP BY subordinate, sub
            ORDER BY subordinate;

        TYPE r_tbl_sub_dtls IS TABLE OF c_sub_dtls%ROWTYPE;

        v_tbl_sub_dtls   r_tbl_sub_dtls;
        v_bulk_limit     NUMBER := 500;
    BEGIN
        OPEN c_sub_dtls;

        LOOP
            FETCH c_sub_dtls
                BULK COLLECT INTO v_tbl_sub_dtls
                LIMIT v_bulk_limit;

            BEGIN
                FORALL i IN 1 .. v_tbl_sub_dtls.COUNT
                    INSERT INTO xxdo.xxd_gl_je_hierarchy_ext_t (
                                    request_id,
                                    subordinate_id,
                                    subordinate,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (gn_request_id, v_tbl_sub_dtls (i).subordinate_id, v_tbl_sub_dtls (i).subordinate, gd_date, gn_user_id, gd_date
                                 , gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Insertion to Staging table failed ' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_sub_dtls%NOTFOUND;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in INSERT_STAGING: ' || SQLERRM);
    END insert_staging;


    --Insertion of Subordinate Supervisors
    PROCEDURE insert_sup_tbl (pn_subordinate_id   IN NUMBER,
                              pv_supervisor       IN VARCHAR2)
    IS
        ln_manager_id   NUMBER := NULL;
    BEGIN
        BEGIN
            SELECT user_id
              INTO ln_manager_id
              FROM fnd_user
             WHERE user_name = pv_supervisor;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_manager_id   := NULL;
        END;

        INSERT INTO xxdo.xxd_gl_je_supervisor_t (request_id,
                                                 subordinate_id,
                                                 manager_id,
                                                 manager,
                                                 creation_date,
                                                 created_by,
                                                 last_update_date,
                                                 last_updated_by)
             VALUES (gn_request_id, pn_subordinate_id, ln_manager_id,
                     pv_supervisor, gd_date, gn_user_id,
                     gd_date, gn_user_id);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'EXP- INSERT_SUP_TBL failed' || SQLERRM);
    END insert_sup_tbl;

    --Insertion of Subordinate Supervisor Hierarchy
    PROCEDURE insert_supervisor_hier
    IS
        ln_count     NUMBER := 0;
        v_sup_tbl    sup_tbl;
        v_sup_tbl2   sup_tbl;
        v_sup_tbl3   sup_tbl;
        v_sup_tbl4   sup_tbl;
        v_sup_tbl5   sup_tbl;

        --Get Subordinates
        CURSOR c_sub IS
            SELECT subordinate_id
              FROM xxdo.xxd_gl_je_hierarchy_ext_t
             WHERE request_id = gn_request_id;

        --Subordinate Supervisor linked with Ledger User Responsiblity users
        CURSOR c_sub_sup (p_sub IN VARCHAR2)
        IS
            SELECT sub_sup_tbl.parent_flex_value_low sub_supervisor
              FROM fnd_user user_dts,
                   (SELECT sub.parent_flex_value_low
                      FROM fnd_flex_values_vl sub,
                           fnd_flex_value_sets subvs,
                           fnd_flex_values_vl sup,
                           fnd_flex_value_sets supvs,
                           (  SELECT furg.user_id
                                FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                               WHERE     furg.responsibility_id =
                                         frv.responsibility_id
                                     AND furg.user_id = fu.user_id
                                     AND UPPER (frv.responsibility_name) LIKE
                                             '%DECKERS%G%LEDGER USER%'
                                     AND NVL (furg.start_date, SYSDATE) <
                                         NVL (
                                             get_end_date_fy (p_cut_off_date,
                                                              furg.end_date),
                                             NVL (furg.start_date, SYSDATE))
                                     AND NVL (
                                             fnd_date.canonical_to_date (
                                                 p_cut_off_date),
                                             SYSDATE) BETWEEN NVL (
                                                                  furg.start_date,
                                                                  SYSDATE)
                                                          AND NVL (
                                                                  get_end_date_fy (
                                                                      p_cut_off_date,
                                                                      furg.end_date),
                                                                  NVL (
                                                                        furg.start_date
                                                                      - 1,
                                                                        SYSDATE
                                                                      - 1))
                                     AND NVL (fu.start_date, SYSDATE) <
                                         NVL (
                                             get_end_date_fy (p_cut_off_date,
                                                              fu.end_date),
                                             NVL (fu.start_date, SYSDATE))
                                     AND NVL (
                                             fnd_date.canonical_to_date (
                                                 p_cut_off_date),
                                             SYSDATE) BETWEEN NVL (
                                                                  fu.start_date,
                                                                  SYSDATE)
                                                          AND NVL (
                                                                  get_end_date_fy (
                                                                      p_cut_off_date,
                                                                      fu.end_date),
                                                                  NVL (
                                                                        fu.start_date
                                                                      - 1,
                                                                        SYSDATE
                                                                      - 1))
                            GROUP BY furg.user_id
                            ORDER BY furg.user_id) res
                     WHERE     1 = 1
                           AND sub.flex_value_set_id =
                               subvs.flex_value_set_id
                           AND sub.enabled_flag = 'Y'
                           AND subvs.flex_value_set_name = 'DO_SUBORDINATES'
                           AND sup.flex_value_set_id =
                               supvs.flex_value_set_id
                           AND sup.enabled_flag = 'Y'
                           AND supvs.flex_value_set_name = 'DO_SUPERVISOR'
                           AND sup.flex_value = sub.parent_flex_value_low
                           AND sub.flex_value <> sub.parent_flex_value_low
                           AND sub.flex_value = res.user_id
                           AND sub.flex_value = p_sub) sub_sup_tbl
             WHERE     user_dts.user_id = sub_sup_tbl.parent_flex_value_low
                   AND NVL (user_dts.start_date, SYSDATE) <
                       NVL (
                           get_end_date_fy (p_cut_off_date,
                                            user_dts.end_date),
                           NVL (user_dts.start_date, SYSDATE))
                   AND NVL (fnd_date.canonical_to_date (p_cut_off_date),
                            SYSDATE) BETWEEN NVL (user_dts.start_date,
                                                  SYSDATE)
                                         AND NVL (
                                                 get_end_date_fy (
                                                     p_cut_off_date,
                                                     user_dts.end_date),
                                                 NVL (
                                                     user_dts.start_date - 1,
                                                     SYSDATE - 1));
    BEGIN
        --Subordinate details
        FOR r_subord IN c_sub
        LOOP
            --Subordinate Supervisor details
            FOR r_sub IN c_sub_sup (r_subord.subordinate_id)
            LOOP
                IF r_sub.sub_supervisor IS NOT NULL
                THEN
                    insert_supervisor_list (
                        p_sub   => r_subord.subordinate_id,
                        p_sup   => r_sub.sub_supervisor);

                    --Supervisor Manager details - 1st level
                    v_sup_tbl   :=
                        get_supervisor (p_sup            => r_sub.sub_supervisor,
                                        p_cut_off_date   => p_cut_off_date);

                    DBMS_OUTPUT.put_line (
                        'Supervisor Mgr Counter loop1 :' || v_sup_tbl.COUNT);

                    FOR i IN 1 .. v_sup_tbl.COUNT
                    LOOP
                        IF v_sup_tbl (i).supervisor IS NOT NULL
                        THEN
                            insert_supervisor_list (
                                p_sub   => r_subord.subordinate_id,
                                p_sup   => v_sup_tbl (i).supervisor);

                            --Supervisor Manager details - 2nd level
                            v_sup_tbl2   :=
                                get_supervisor (
                                    p_sup            => v_sup_tbl (i).supervisor,
                                    p_cut_off_date   => p_cut_off_date);

                            DBMS_OUTPUT.put_line (
                                   'Supervisor Mgr Counter loop2 :'
                                || v_sup_tbl2.COUNT);

                            FOR i IN 1 .. v_sup_tbl2.COUNT
                            LOOP
                                IF v_sup_tbl2 (i).supervisor IS NOT NULL
                                THEN
                                    insert_supervisor_list (
                                        p_sub   => r_subord.subordinate_id,
                                        p_sup   => v_sup_tbl2 (i).supervisor);

                                    --Supervisor Manager details - 3rd level
                                    v_sup_tbl3   :=
                                        get_supervisor (
                                            p_sup            =>
                                                v_sup_tbl2 (i).supervisor,
                                            p_cut_off_date   => p_cut_off_date);

                                    DBMS_OUTPUT.put_line (
                                           'Supervisor Mgr Counter loop3 :'
                                        || v_sup_tbl3.COUNT);

                                    FOR i IN 1 .. v_sup_tbl3.COUNT
                                    LOOP
                                        IF v_sup_tbl3 (i).supervisor
                                               IS NOT NULL
                                        THEN
                                            insert_supervisor_list (
                                                p_sub   =>
                                                    r_subord.subordinate_id,
                                                p_sup   =>
                                                    v_sup_tbl3 (i).supervisor);

                                            --Supervisor Manager details - 4th level
                                            v_sup_tbl4   :=
                                                get_supervisor (
                                                    p_sup   =>
                                                        v_sup_tbl3 (i).supervisor,
                                                    p_cut_off_date   =>
                                                        p_cut_off_date);

                                            FOR i IN 1 .. v_sup_tbl4.COUNT
                                            LOOP
                                                IF v_sup_tbl4 (i).supervisor
                                                       IS NOT NULL
                                                THEN
                                                    insert_supervisor_list (
                                                        p_sub   =>
                                                            r_subord.subordinate_id,
                                                        p_sup   =>
                                                            v_sup_tbl4 (i).supervisor);

                                                    --Supervisor Manager details - 5th level
                                                    v_sup_tbl5   :=
                                                        get_supervisor (
                                                            p_sup   =>
                                                                v_sup_tbl4 (
                                                                    i).supervisor,
                                                            p_cut_off_date   =>
                                                                p_cut_off_date);

                                                    FOR i IN 1 ..
                                                             v_sup_tbl5.COUNT
                                                    LOOP
                                                        IF v_sup_tbl5 (i).supervisor
                                                               IS NOT NULL
                                                        THEN
                                                            insert_supervisor_list (
                                                                p_sub   =>
                                                                    r_subord.subordinate_id,
                                                                p_sup   =>
                                                                    v_sup_tbl5 (
                                                                        i).supervisor);
                                                        END IF;
                                                    END LOOP;      --5th Level
                                                END IF;
                                            END LOOP;              --4th Level
                                        END IF;
                                    END LOOP;                      --3rd Level
                                END IF;
                            END LOOP;                              --2nd Level
                        END IF;
                    END LOOP;                                      --Ist Level

                    COMMIT;
                END IF;
            END LOOP;                                              --c_sub_sup
        END LOOP;                                                      --c_sub
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' EXP - INSERT_SUPERVISOR_HIER :' || SQLERRM);
    END insert_supervisor_hier;

    --Get Supervisor Hierarchy linked with Ledger Manager Responsiblity users
    FUNCTION get_supervisor (p_sup IN VARCHAR2, p_cut_off_date IN VARCHAR2)
        RETURN sup_tbl
    IS
        CURSOR c_sup_mgr IS
            SELECT sub_sup_tbl.parent_flex_value_low supervisor
              FROM fnd_user user_dts,
                   (SELECT sub.parent_flex_value_low
                      FROM fnd_flex_values_vl sub,
                           fnd_flex_value_sets subvs,
                           fnd_flex_values_vl sup,
                           fnd_flex_value_sets supvs,
                           (  SELECT furg.user_id
                                FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                               WHERE     furg.responsibility_id =
                                         frv.responsibility_id
                                     AND furg.user_id = fu.user_id
                                     AND UPPER (frv.responsibility_name) LIKE
                                             '%DECKERS%G%LEDGER MANAGER%'
                                     AND NVL (furg.start_date, SYSDATE) <
                                         NVL (
                                             get_end_date_fy (p_cut_off_date,
                                                              furg.end_date),
                                             NVL (furg.start_date, SYSDATE))
                                     AND NVL (
                                             fnd_date.canonical_to_date (
                                                 p_cut_off_date),
                                             SYSDATE) BETWEEN NVL (
                                                                  furg.start_date,
                                                                  SYSDATE)
                                                          AND NVL (
                                                                  get_end_date_fy (
                                                                      p_cut_off_date,
                                                                      furg.end_date),
                                                                  NVL (
                                                                        furg.start_date
                                                                      - 1,
                                                                        SYSDATE
                                                                      - 1))
                                     AND NVL (fu.start_date, SYSDATE) <
                                         NVL (
                                             get_end_date_fy (p_cut_off_date,
                                                              fu.end_date),
                                             NVL (fu.start_date, SYSDATE))
                                     AND NVL (
                                             fnd_date.canonical_to_date (
                                                 p_cut_off_date),
                                             SYSDATE) BETWEEN NVL (
                                                                  fu.start_date,
                                                                  SYSDATE)
                                                          AND NVL (
                                                                  get_end_date_fy (
                                                                      p_cut_off_date,
                                                                      fu.end_date),
                                                                  NVL (
                                                                        fu.start_date
                                                                      - 1,
                                                                        SYSDATE
                                                                      - 1))
                            GROUP BY furg.user_id
                            ORDER BY furg.user_id) res
                     WHERE     1 = 1
                           AND sub.flex_value_set_id =
                               subvs.flex_value_set_id
                           AND sub.enabled_flag = 'Y'
                           AND subvs.flex_value_set_name = 'DO_SUBORDINATES'
                           AND sup.flex_value_set_id =
                               supvs.flex_value_set_id
                           AND sup.enabled_flag = 'Y'
                           AND supvs.flex_value_set_name = 'DO_SUPERVISOR'
                           AND sup.flex_value = sub.parent_flex_value_low
                           AND sub.flex_value <> sub.parent_flex_value_low
                           AND sub.flex_value = res.user_id
                           AND sub.flex_value = p_sup) sub_sup_tbl
             WHERE     user_dts.user_id = sub_sup_tbl.parent_flex_value_low
                   AND NVL (user_dts.start_date, SYSDATE) <
                       NVL (
                           get_end_date_fy (p_cut_off_date,
                                            user_dts.end_date),
                           NVL (user_dts.start_date, SYSDATE))
                   AND NVL (fnd_date.canonical_to_date (p_cut_off_date),
                            SYSDATE) BETWEEN NVL (user_dts.start_date,
                                                  SYSDATE)
                                         AND NVL (
                                                 get_end_date_fy (
                                                     p_cut_off_date,
                                                     user_dts.end_date),
                                                 NVL (
                                                     user_dts.start_date - 1,
                                                     SYSDATE - 1));

        --Type variables
        v_sup_tbl   sup_tbl;
    BEGIN
        LOOP
            OPEN c_sup_mgr;

            FETCH c_sup_mgr BULK COLLECT INTO v_sup_tbl;

            CLOSE c_sup_mgr;

            EXIT;
        END LOOP;

        --dbms_output.put_line(' Supervisor Mgr Counter loop : ' || v_sup_tbl.COUNT);

        RETURN v_sup_tbl;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'EXP -OTHERS in GET_SUPERVISOR: ' || SQLERRM);
            RETURN v_sup_tbl;
    END get_supervisor;

    --Insert Supervisor list in Staging
    PROCEDURE insert_supervisor_list (p_sub IN VARCHAR2, p_sup IN VARCHAR2)
    IS
        lv_supervisor   VARCHAR2 (200) := NULL;
    BEGIN
        IF p_sup IS NOT NULL
        THEN
            BEGIN
                SELECT (SELECT user_name
                          FROM fnd_user
                         WHERE user_id = flex_value) sup_manager
                  INTO lv_supervisor
                  FROM fnd_flex_values_vl sup, fnd_flex_value_sets supvs
                 WHERE     sup.flex_value_set_id = supvs.flex_value_set_id
                       AND supvs.flex_value_set_name = 'DO_SUPERVISOR'
                       AND sup.enabled_flag = 'Y'
                       AND flex_value = p_sup
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_supervisor   := NULL;
            END;

            IF lv_supervisor IS NOT NULL
            THEN
                insert_sup_tbl (pn_subordinate_id   => p_sub,
                                pv_supervisor       => lv_supervisor);
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'EXP -OTHERS in GET_SUPERVISOR: ' || SQLERRM);
    END insert_supervisor_list;

    --Validate and Remove if Subordinate as Manager
    PROCEDURE validate_duplication
    IS
        lv_remove_sub   VARCHAR2 (100) := NULL;

        --Get Subordinate as Manager
        CURSOR c_sub_mgr IS
            SELECT DISTINCT sup.manager_id
              FROM xxdo.xxd_gl_je_supervisor_t sup, xxdo.xxd_gl_je_hierarchy_ext_t sub
             WHERE     sup.manager_id = sub.subordinate_id
                   AND sup.request_id = sub.request_id
                   AND sub.request_id = gn_request_id;

        TYPE r_sub_mgr IS TABLE OF c_sub_mgr%ROWTYPE;

        v_sub_mgr       r_sub_mgr;
        v_bulk_limit    NUMBER := 100;
    BEGIN
        --Remove if Manager as Duplicate in list
        BEGIN
            DELETE FROM
                xxdo.xxd_gl_je_supervisor_t sup
                  WHERE     ROWID NOT IN
                                (  SELECT MIN (ROWID)
                                     FROM xxdo.xxd_gl_je_supervisor_t sup1
                                    WHERE     1 = 1
                                          AND sup.subordinate_id =
                                              sup1.subordinate_id
                                          AND sup.manager_id = sup1.manager_id
                                          AND sup.request_id = sup1.request_id
                                 GROUP BY request_id, subordinate_id, manager_id)
                        --AND subordinate_id = ln_subordinate_id
                        AND request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Duplication deletion failed in Superivisor Table'
                    || SQLERRM);
        END;

        --Validate if Subordinate as Manager and Update in Staging
        OPEN c_sub_mgr;

        LOOP
            FETCH c_sub_mgr BULK COLLECT INTO v_sub_mgr LIMIT v_bulk_limit;

            BEGIN
                FORALL i IN 1 .. v_sub_mgr.COUNT
                    UPDATE xxdo.xxd_gl_je_hierarchy_ext_t
                       SET sub_mgr_exists   = 'Y'
                     WHERE     request_id = gn_request_id
                           AND subordinate_id = v_sub_mgr (i).manager_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updation of Subordinates Exists as Manager failed'
                        || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_sub_mgr%NOTFOUND;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'EXP - validate_duplication :' || SQLERRM);
    END validate_duplication;

    --Re-check Responsibility Dates if Subordinate as Manager
    PROCEDURE recheck_mgr_resp_dt
    IS
        ln_usr_resp_exists   NUMBER := 0;
        ln_mgr_resp_exists   NUMBER := 0;

        --Get Subordinate as Manager for Re-validation
        CURSOR c_sub_mgr_resp_chk IS
            SELECT DISTINCT sup.manager_id
              FROM xxdo.xxd_gl_je_supervisor_t sup, xxdo.xxd_gl_je_hierarchy_ext_t sub
             WHERE     sup.manager_id = sub.subordinate_id
                   AND sup.request_id = sub.request_id
                   AND NVL (sub.sub_mgr_exists, 'N') = 'Y'
                   AND sub.request_id = gn_request_id;
    BEGIN
        --Re-check User\Manager Responsibility dates if Subordinate as Manager
        FOR r_sub_mgr_resp IN c_sub_mgr_resp_chk
        LOOP
            --Revalidate if Manager Enddate exists in %User%Responsibility
            BEGIN
                  SELECT COUNT (1)
                    INTO ln_usr_resp_exists
                    FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                   WHERE     furg.responsibility_id = frv.responsibility_id
                         AND furg.user_id = fu.user_id
                         AND UPPER (frv.responsibility_name) LIKE
                                 '%DECKERS%G%LEDGER USER%'
                         AND NVL (fnd_date.canonical_to_date (p_cut_off_date),
                                  SYSDATE) BETWEEN NVL (furg.start_date,
                                                        SYSDATE)
                                               AND NVL (
                                                       get_end_date_fy (
                                                           p_cut_off_date,
                                                           furg.end_date),
                                                       NVL (
                                                           furg.start_date - 1,
                                                           SYSDATE - 1))
                         AND furg.user_id = r_sub_mgr_resp.manager_id
                GROUP BY furg.user_id
                ORDER BY furg.user_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_usr_resp_exists   := -1;
            END;

            --Revalidate if Manager Startdate exists in %Manager%Responsibility
            BEGIN
                  SELECT COUNT (1)
                    INTO ln_mgr_resp_exists
                    FROM apps.fnd_user_resp_groups_direct furg, apps.fnd_responsibility_vl frv, apps.fnd_user fu
                   WHERE     furg.responsibility_id = frv.responsibility_id
                         AND furg.user_id = fu.user_id
                         AND UPPER (frv.responsibility_name) LIKE
                                 '%DECKERS%G%LEDGER MANAGER%'
                         AND (NVL (furg.start_date, SYSDATE) > NVL (fnd_date.canonical_to_date (p_cut_off_date), SYSDATE) OR (NVL (furg.start_date, SYSDATE) <= NVL (fnd_date.canonical_to_date (p_cut_off_date), SYSDATE) AND NVL (fnd_date.canonical_to_date (p_cut_off_date), SYSDATE) BETWEEN NVL (furg.start_date, SYSDATE) AND NVL (get_end_date_fy (p_cut_off_date, furg.start_date), NVL (furg.start_date - 1, SYSDATE - 1))))
                         AND furg.user_id = r_sub_mgr_resp.manager_id
                GROUP BY furg.user_id
                ORDER BY furg.user_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_mgr_resp_exists   := -1;
            END;

            --Post Re-validation, updation of sub_mgr_exists flag
            IF (NVL (ln_usr_resp_exists, 0) > 0 AND NVL (ln_mgr_resp_exists, 0) > 0)
            THEN
                BEGIN
                    UPDATE xxdo.xxd_gl_je_hierarchy_ext_t
                       SET sub_mgr_exists   = 'N'
                     WHERE     request_id = gn_request_id
                           AND subordinate_id = r_sub_mgr_resp.manager_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'EXP - Updation in recheck_mgr_resp_dt :'
                            || SQLERRM);
                END;

                --Remove Duplication in Supervisor list if Subordinate exists
                BEGIN
                    DELETE FROM
                        xxdo.xxd_gl_je_supervisor_t t
                          WHERE     request_id = gn_request_id
                                AND manager_id = subordinate_id
                                AND subordinate_id =
                                    r_sub_mgr_resp.manager_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'EXP - Deletion in recheck_mgr_resp_dt :'
                            || SQLERRM);
                END;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'EXP - recheck_mgr_resp_dt :' || SQLERRM);
    END recheck_mgr_resp_dt;

    --Get Supervisor Hierarchy
    FUNCTION get_sup_list (p_subordinate_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_supervisor_list   VARCHAR2 (500) := NULL;
        ln_subordinate_id    NUMBER;
    BEGIN
        BEGIN
              --Get Subordinate Supervisors
              SELECT subordinate_id, LISTAGG (manager, ',') WITHIN GROUP (ORDER BY subordinate_id) manager
                INTO ln_subordinate_id, lv_supervisor_list
                FROM xxdo.xxd_gl_je_supervisor_t t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND subordinate_id = p_subordinate_id
            GROUP BY subordinate_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_supervisor_list   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Insertion to Staging table failed' || SQLERRM);
        END;

        RETURN lv_supervisor_list;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'EXP -OTHERS in GET_SUP_LIST: ' || SQLERRM);
            lv_supervisor_list   := NULL;
            RETURN lv_supervisor_list;
    END get_sup_list;

    --To get Fisical Year Period End Date
    FUNCTION get_end_date_fy (p_cut_off_date IN VARCHAR2, p_end_date IN DATE)
        RETURN DATE
    IS
        ln_period_year     NUMBER;
        ld_yr_start_date   DATE;
        ld_yr_end_date     DATE;
        ld_end_date_fy     DATE;
        ld_cut_off_date    DATE
                               := fnd_date.canonical_to_date (p_cut_off_date); --SYSDATE- 365;
        ld_end_date        DATE := NVL (p_end_date, ld_cut_off_date);
    BEGIN
        IF p_cut_off_date IS NULL
        THEN
            ld_end_date_fy   := SYSDATE + 1;
        ELSE
            BEGIN
                SELECT DISTINCT period_year
                  INTO ln_period_year
                  FROM gl_periods
                 WHERE     1 = 1
                       AND period_set_name = 'DO_FY_CALENDAR'
                       AND (ld_cut_off_date BETWEEN year_start_date AND (ADD_MONTHS (year_start_date, 12) - 1));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_period_year   := NULL;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Exp- ln_period_year :' || SQLERRM);
            END;

            BEGIN
                SELECT DISTINCT year_start_date, ADD_MONTHS (year_start_date, 12) - 1 year_end_date
                  INTO ld_yr_start_date, ld_yr_end_date
                  FROM gl_periods
                 WHERE     1 = 1
                       AND period_set_name = 'DO_FY_CALENDAR'
                       AND period_year = ln_period_year;                --2022
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_yr_start_date   := NULL;
                    ld_yr_end_date     := NULL;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Exp- ld_yr_end_date :' || SQLERRM);
            END;
        END IF;

        IF (ld_end_date BETWEEN ld_yr_start_date AND ld_yr_end_date)
        THEN
            ld_end_date_fy   := ld_yr_end_date;
        ELSIF (ld_end_date > ld_yr_end_date)
        THEN
            ld_end_date_fy   := ld_yr_end_date;
        ELSE
            ld_end_date_fy   := NULL;                       --ld_cut_off_date;
        END IF;

        RETURN ld_end_date_fy;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exp- fun_get_end_date_fy :' || SQLERRM);
            RETURN NULL;
    END get_end_date_fy;
END XXD_GL_JE_HIERARCHY_EXT_PKG;
/
