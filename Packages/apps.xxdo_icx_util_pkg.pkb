--
-- XXDO_ICX_UTIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_ICX_UTIL_PKG
AS
    /*******************************************************************************
   * Program Name : XXDO_ICX_UTIL_PKG
   * Language     : PL/SQL
   * Description  : This package will get org_id mapped to given project
   *
   * History      :
   *
   * WHO            WHAT              Desc                             WHEN
   * -------------- ---------------------------------------------- ---------------
   * Swapna N          1.0 - Initial Version                         AUG/6/2014
   * --------------------------------------------------------------------------- */

    FUNCTION get_PROJECT_MAPPED_ORG_ID (p_project_Id IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_proj_org_id          VARCHAR2 (240) DEFAULT NULL;
        l_org_id               NUMBER;
        v_stmt_str             VARCHAR2 (5000);
        l_no                   VARCHAR2 (1) := 'N';
        l_yes                  VARCHAR2 (1) := 'Y';

        TYPE orgId IS REF CURSOR;

        v_proj_org_id_cursor   orgID;
        ln_loop                NUMBER DEFAULT (1);
    BEGIN
        v_stmt_str   :=
            'SELECT DISTINCT prl.organization_id
  FROM pa_budget_versions pbv,
       pa_budget_lines_v pblv,
       pa_resource_list_members prl,
       PA_Projects_all ppa
 WHERE     pbv.budget_version_id = pblv.budget_version_id
       AND pblv.resource_list_member_id = prl.resource_list_member_id
       AND pbv.budget_type_code = ''Cost Center Budget''
       AND EXISTS
              (SELECT 1
                 FROM pa_resource_lists prls
                WHERE     prls.resource_list_id = pbv.resource_list_id
                      AND prl.resource_list_id = prls.resource_list_id
                      AND prls.NAME = ''Expenditure Org Resource List'')
       AND (   pbv.budget_status_code = ''W''
            OR (    pbv.budget_status_code = ''B''
                AND pbv.budget_version_id =
                       (SELECT MAX (budget_version_id)
                          FROM pa_budget_versions pbv1
                         WHERE     pbv1.budget_type_code =
                                      pbv.budget_type_code
                               AND pbv1.project_id = pbv.project_id
                               AND pbv1.resource_list_id =
                                      pbv.resource_list_id))) and pbv.project_id  =:p_project_id ';

        -- Open cursor and specify bind variable in USING clause:
        OPEN v_proj_org_id_cursor FOR v_stmt_str USING p_project_id;

        l_org_id   := NULL;

        -- Fetch rows from result set one at a time:
        LOOP
            FETCH v_proj_org_id_cursor INTO l_org_id;

            EXIT WHEN v_proj_org_id_cursor%NOTFOUND;

            IF l_org_id IS NOT NULL
            THEN
                IF ln_loop = 1
                THEN
                    l_proj_org_id   := TO_CHAR (l_org_id);
                ELSE
                    l_proj_org_id   :=
                        l_proj_org_id || ',' || TO_CHAR (l_org_id);
                END IF;

                ln_loop   := ln_loop + 1;
            END IF;

            EXIT WHEN v_proj_org_id_cursor%NOTFOUND;
        END LOOP;

        -- Close cursor:
        CLOSE v_proj_org_id_cursor;

        RETURN l_proj_org_id;
    END get_PROJECT_MAPPED_ORG_ID;
END XXDO_ICX_UTIL_PKG;
/
