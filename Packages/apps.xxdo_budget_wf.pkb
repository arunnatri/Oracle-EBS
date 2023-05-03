--
-- XXDO_BUDGET_WF  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_budget_wf
AS
    /*******************************************************************************
    * Program Name : XXDO_BUDGET_WF
    * Language  : PL/SQL
    * Description  : This package is used for Budget approval workflow
    *
    *
    *   WHO    Version  when   Desc
    * --------------------------------------------------------------------------
    * BT Technology Team   1.0    21/Jan/2015  workflow Prog
    * --------------------------------------------------------------------------- */
    PROCEDURE CURRENCY_CONVERSION_OK (itemtype    IN            VARCHAR2,
                                      itemkey     IN            VARCHAR2,
                                      actid       IN            NUMBER,
                                      funcmode    IN            VARCHAR2,
                                      resultout      OUT NOCOPY VARCHAR2)
    IS
        V_CURRENCY_CODE             VARCHAR2 (100);
        V_PROJECT_ID                NUMBER;
        V_TOTAL_BURDENED_COST       NUMBER;
        V_CONVERSION_RATE           NUMBER;
        V_CONVERTED_BURDENED_COST   NUMBER;
        l_err_code                  NUMBER := 0;
        l_msg_count                 NUMBER;
        l_msg_data                  VARCHAR (2000);
        l_return_status             VARCHAR2 (1);
    BEGIN
        --
        -- Return if WF Not Running
        --
        IF (funcmode <> wf_engine.eng_run)
        THEN
            --
            resultout   := wf_engine.eng_null;
            RETURN;
        --
        END IF;

        ----

        V_PROJECT_ID   :=
            wf_engine.GetItemAttrNumber (itemtype   => itemtype,
                                         itemkey    => itemkey,
                                         aname      => 'PROJECT_ID');

        -- SET GLOBALS -----------------------------------------------------------------

        -- Based on the Responsibility, Intialize the Application
        /*Commented for bug 5233870*/
        -- Un Commented for bug 8464143.
        PA_WORKFLOW_UTILS.Set_Global_Attr (p_item_type   => itemtype,
                                           p_item_key    => itemkey,
                                           p_err_code    => l_err_code);


        -- R12 MOAC, 19-JUL-05, jwhite -------------------
        -- Set Single Project/OU context

        PA_BUDGET_UTILS.Set_Prj_Policy_Context (
            p_project_id      => V_PROJECT_ID,
            x_return_status   => l_return_status,
            x_msg_count       => l_msg_count,
            x_msg_data        => l_msg_data,
            x_err_code        => l_err_code);

        IF (l_err_code <> 0)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- -----------------------------------------------

        SELECT PROJECT_CURRENCY_CODE
          INTO V_CURRENCY_CODE
          FROM apps.pa_projects_all
         WHERE project_id = V_PROJECT_ID;

        wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'BUDGET_CURRENCY'
                                   , avalue => V_CURRENCY_CODE);

        V_TOTAL_BURDENED_COST   :=
            wf_engine.GetItemAttrNumber (itemtype   => itemtype,
                                         itemkey    => itemkey,
                                         aname      => 'TOTAL_BURDENED_COST');

        IF V_CURRENCY_CODE = 'USD'
        THEN
            wf_engine.SetItemAttrNumber (itemtype => itemtype, itemkey => itemkey, aname => 'XXD_TOTAL_BURDENED_COST'
                                         , avalue => V_TOTAL_BURDENED_COST);
            resultout   := wf_engine.eng_completed || ':' || 'T';
        ELSE
            BEGIN
                SELECT CONVERSION_RATE
                  INTO V_CONVERSION_RATE
                  FROM gl_daily_rates
                 WHERE     conversion_type = 'Corporate'
                       AND CONVERSION_DATE = TRUNC (SYSDATE)
                       AND FROM_CURRENCY = V_CURRENCY_CODE
                       AND TO_CURRENCY = 'USD';



                V_CONVERTED_BURDENED_COST   :=
                    V_TOTAL_BURDENED_COST * V_CONVERSION_RATE;

                wf_engine.SetItemAttrNumber (
                    itemtype   => itemtype,
                    itemkey    => itemkey,
                    aname      => 'XXD_TOTAL_BURDENED_COST',
                    avalue     => V_CONVERTED_BURDENED_COST);


                resultout   := wf_engine.eng_completed || ':' || 'T';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    resultout   := wf_engine.eng_completed || ':' || 'F';
            END;
        END IF;
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'CURRENCY_CONVERSION_OK', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
        WHEN OTHERS
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'CURRENCY_CONVERSION_OK', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END;

    PROCEDURE SELECT_GB_BUSINESS_OWNER (itemtype    IN            VARCHAR2,
                                        itemkey     IN            VARCHAR2,
                                        actid       IN            NUMBER,
                                        funcmode    IN            VARCHAR2,
                                        resultout      OUT NOCOPY VARCHAR2)
    IS
        CURSOR C_GET_OWNERS (P_ROLE VARCHAR2)
        IS
            SELECT f.user_id, f.user_name, e.first_name || ' ' || e.last_name
              FROM PA_PROJECT_ROLE_TYPES PPRT, pa_project_players PPP, pa_projects_all PPA,
                   fnd_user f, pa_employees e
             WHERE     PPA.NAME = 'GLOBAL BUDGET APPROVER'
                   AND PPRT.PROJECT_ROLE_TYPE = PPP.PROJECT_ROLE_TYPE
                   AND TRUNC (SYSDATE) BETWEEN ppp.start_date_ACTIVE
                                           AND NVL (ppp.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1)
                   AND UPPER (PPRT.MEANING) = UPPER (P_ROLE)
                   AND PPP.PROJECT_ID = PPA.PROJECT_ID
                   AND f.employee_id = PPP.PERSON_ID
                   AND f.employee_id = e.person_id
                   AND TRUNC (SYSDATE) BETWEEN F.start_date
                                           AND NVL (f.end_date,
                                                    TRUNC (SYSDATE) + 1)
                   AND TRUNC (SYSDATE) BETWEEN PPRT.start_date_ACTIVE
                                           AND NVL (PPRT.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1);

        --AND PPRT.CREATION_DATE ;

        V_GLOBALOWNER_user_id     VARCHAR2 (100);
        V_GLOBALOWNER_full_name   VARCHAR2 (100);
        V_PROJECT_TYPE            VARCHAR2 (100);
        V_GLOBALOWNER_user_name   VARCHAR2 (100);
        V_PROJECT_ID              NUMBER;
        V_ROLE                    VARCHAR2 (100);
        l_err_code                NUMBER := 0;
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR (2000);
        l_return_status           VARCHAR2 (1);
        l_approver_role           VARCHAR2 (50);
    BEGIN
        --
        -- Return if WF Not Running
        --
        IF (funcmode <> wf_engine.eng_run)
        THEN
            --
            resultout   := wf_engine.eng_null;
            RETURN;
        --
        END IF;

        ----



        V_PROJECT_ID   :=
            wf_engine.GetItemAttrNumber (itemtype   => itemtype,
                                         itemkey    => itemkey,
                                         aname      => 'PROJECT_ID');

        V_PROJECT_TYPE   :=
            wf_engine.GetItemAttrText (itemtype   => itemtype,
                                       itemkey    => itemkey,
                                       aname      => 'PROJECT_TYPE');

        -- SET GLOBALS -----------------------------------------------------------------

        -- Based on the Responsibility, Intialize the Application
        /*Commented for bug 5233870*/
        -- Un Commented for bug 8464143.
        PA_WORKFLOW_UTILS.Set_Global_Attr (p_item_type   => itemtype,
                                           p_item_key    => itemkey,
                                           p_err_code    => l_err_code);


        -- R12 MOAC, 19-JUL-05, jwhite -------------------
        -- Set Single Project/OU context

        PA_BUDGET_UTILS.Set_Prj_Policy_Context (
            p_project_id      => V_PROJECT_ID,
            x_return_status   => l_return_status,
            x_msg_count       => l_msg_count,
            x_msg_data        => l_msg_data,
            x_err_code        => l_err_code);

        IF (l_err_code <> 0)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        ----------------
        -- Changes By BT Technology Team on 06-MAR-2015--
        -- the following code is commented out (on 06-Mar-2015 following a RIDD raised by A2R Team) to dynamically fetch the business owner based on project type
        --so that in case a new project type gets added the busniess owner for that type can be configured using a lookup value---
        /*  IF UPPER (V_PROJECT_TYPE) LIKE 'IT%'
          THEN
             V_ROLE := 'Global IT Business Owner';
          ELSIF UPPER (V_PROJECT_TYPE) LIKE 'RETAIL%'
          THEN
             V_ROLE := 'Global Retail Business Owner';
          ELSIF UPPER (V_PROJECT_TYPE) LIKE 'SUPPLY CHAIN%'
          THEN
             V_ROLE := 'Global Supply Chain Business Owner';
          END IF;*/

        -- Added By BT Technology Team on 06-MAR-2015--
        --the following query retrieves the global Business owner depending on the respective project type from the lookup---

        SELECT segment_value
          INTO V_ROLE
          FROM pa_segment_value_lookup_sets x, pa_segment_value_lookups y
         WHERE     x.segment_value_lookup_set_id =
                   y.segment_value_lookup_set_id
               AND x.segment_value_lookup_set_name =
                   'XXDO_PROJ_TYPE_BUD_APP_MAP_L1'
               AND UPPER (y.segment_value_lookup) = UPPER (V_PROJECT_TYPE)
               AND ROWNUM = 1;

        wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'GLOBAL_BUSINESS_OWNER'
                                   , avalue => V_ROLE);

        OPEN C_GET_OWNERS (V_ROLE);

        FETCH C_GET_OWNERS INTO V_GLOBALOWNER_user_id, V_GLOBALOWNER_user_name, V_GLOBALOWNER_full_name;

        IF (C_GET_OWNERS%FOUND)
        THEN
            CLOSE C_GET_OWNERS;

            wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_BUSINESS_ID'
                                       , avalue => V_GLOBALOWNER_user_id);

            wf_engine.SetItemAttrtext (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_BUSINESS_USERNAME'
                                       , avalue => V_GLOBALOWNER_user_name);

            wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_BUSINESS_FULLNAME'
                                       , avalue => V_GLOBALOWNER_full_name);

            wf_engine.SetItemAttrText (
                itemtype   => itemtype,
                itemkey    => itemkey,
                aname      => 'XXDO_TIMEOUT_L1',
                avalue     =>
                    FND_PROFILE.VALUE (
                        'XXDO_PA_BUDGET_NOTIFICATION_TIMEOUT_L1'));



            wf_engine.SetItemAttrText (
                itemtype   => itemtype,
                itemkey    => itemkey,
                aname      => 'XXDO_LOOP_COUNT_L1',
                avalue     =>
                    FND_PROFILE.VALUE (
                        'XXDO_PA_BUDGET_NOTIFICATION_LOOP_COUNT_L1'));

            l_approver_role   :=
                   'APPR_'
                || itemtype
                || itemkey
                || TO_CHAR (SYSDATE, 'Jsssss')
                || 'owner';

            WF_DIRECTORY.CreateAdHocRole (
                role_name           => l_approver_role,
                role_display_name   => V_GLOBALOWNER_full_name,
                expiration_date     => SYSDATE + 1);

            wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => '#FROM_ROLE'
                                       , avalue => l_approver_role);

            resultout   := wf_engine.eng_completed || ':' || 'T';
        ELSE
            CLOSE C_GET_OWNERS;

            resultout   := wf_engine.eng_completed || ':' || 'F';
        END IF;
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'SELECT_GB_BUSINESS_OWNER', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
        WHEN OTHERS
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'SELECT_GB_BUSINESS_OWNER', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END;

    PROCEDURE FPA_APPROVAL_REQUIRED (itemtype    IN            VARCHAR2,
                                     itemkey     IN            VARCHAR2,
                                     actid       IN            NUMBER,
                                     funcmode    IN            VARCHAR2,
                                     resultout      OUT NOCOPY VARCHAR2)
    IS
        -----------------
        -- Changes By BT Technology Team on 06-MAR-2015--
        --Cursor chnaged on 06-Mar-2015 to consider the FP&A Owner Dynamically from Project Type--
        /*CURSOR C_GET_OWNERS
        IS
           SELECT f.user_id, f.user_name, e.first_name || ' ' || e.last_name
             FROM PA_PROJECT_ROLE_TYPES PPRT,
                  pa_project_players PPP,
                  pa_projects_all PPA,
                  fnd_user f,
                  pa_employees e
            WHERE PPA.NAME = 'GLOBAL BUDGET APPROVER'
                  AND PPRT.PROJECT_ROLE_TYPE = PPP.PROJECT_ROLE_TYPE
                  AND TRUNC (SYSDATE) BETWEEN ppp.start_date_ACTIVE
                                          AND  NVL (ppp.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1)
                  AND PPRT.MEANING = 'Global FP&A Owner'
                  AND PPP.PROJECT_ID = PPA.PROJECT_ID
                  AND f.employee_id = PPP.PERSON_ID
                  AND f.employee_id = e.person_id
                  AND TRUNC (SYSDATE) BETWEEN F.start_date
                                          AND  NVL (f.end_date,
                                                    TRUNC (SYSDATE) + 1)
                  AND TRUNC (SYSDATE) BETWEEN PPRT.start_date_ACTIVE
                                          AND  NVL (PPRT.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1);*/

        -- Added By BT Technology Team on 06-MAR-2015--
        -- a parameter has been added to the cursor to fetch the seconda level approver dynamically--
        CURSOR C_GET_OWNERS (p_role IN VARCHAR2)
        IS
            SELECT f.user_id, f.user_name, e.first_name || ' ' || e.last_name
              FROM PA_PROJECT_ROLE_TYPES PPRT, pa_project_players PPP, pa_projects_all PPA,
                   fnd_user f, pa_employees e
             WHERE     PPA.NAME = 'GLOBAL BUDGET APPROVER'
                   AND PPRT.PROJECT_ROLE_TYPE = PPP.PROJECT_ROLE_TYPE
                   AND TRUNC (SYSDATE) BETWEEN ppp.start_date_ACTIVE
                                           AND NVL (ppp.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1)
                   AND PPRT.MEANING = p_role
                   AND PPP.PROJECT_ID = PPA.PROJECT_ID
                   AND f.employee_id = PPP.PERSON_ID
                   AND f.employee_id = e.person_id
                   AND TRUNC (SYSDATE) BETWEEN F.start_date
                                           AND NVL (f.end_date,
                                                    TRUNC (SYSDATE) + 1)
                   AND TRUNC (SYSDATE) BETWEEN PPRT.start_date_ACTIVE
                                           AND NVL (PPRT.end_date_ACTIVE,
                                                    TRUNC (SYSDATE) + 1);

        --AND PPRT.CREATION_DATE ;
        V_GLOBALOWNER_user_id     VARCHAR2 (100);
        V_GLOBALOWNER_full_name   VARCHAR2 (100);
        l_role                    VARCHAR2 (100);
        V_PROJECT_TYPE            VARCHAR2 (100);
        V_GLOBALOWNER_user_name   VARCHAR2 (100);
        V_GLOBAL_FPA_user_id      VARCHAR2 (100);
        V_GLOBAL_FPA_full_name    VARCHAR2 (100);
        V_GLOBAL_FPA_user_name    VARCHAR2 (100);
        V_PROJECT_ID              NUMBER;
        v_draft_version_id        NUMBER;
        V_VERSION_NUMBER          NUMBER;
        V_TOTAL_BURDENED_COST     NUMBER;
        V_PROFILE_NAME            VARCHAR2 (100);
        v_level_value             NUMBER;
        l_err_code                NUMBER := 0;
        l_msg_count               NUMBER;
        l_msg_data                VARCHAR (2000);
        l_return_status           VARCHAR2 (1);
        l_approver_role           VARCHAR2 (50);
        V_DOCUMENT_ID             CLOB;
        v_itemkey                 NUMBER;
    BEGIN
        --
        -- Return if WF Not Running
        --
        IF (funcmode <> wf_engine.eng_run)
        THEN
            --
            resultout   := wf_engine.eng_null;
            RETURN;
        --
        END IF;

        v_draft_version_id   :=
            wf_engine.GetItemAttrNumber (itemtype   => itemtype,
                                         itemkey    => itemkey,
                                         aname      => 'DRAFT_VERSION_ID');


        V_PROJECT_ID   :=
            wf_engine.GetItemAttrNumber (itemtype   => itemtype,
                                         itemkey    => itemkey,
                                         aname      => 'PROJECT_ID');

        V_PROJECT_TYPE   :=
            wf_engine.GetItemAttrText (itemtype   => itemtype,
                                       itemkey    => itemkey,
                                       aname      => 'PROJECT_TYPE');

        V_TOTAL_BURDENED_COST   :=
            wf_engine.GetItemAttrNumber (
                itemtype   => itemtype,
                itemkey    => itemkey,
                aname      => 'XXD_TOTAL_BURDENED_COST');

        -- SET GLOBALS -----------------------------------------------------------------

        -- Based on the Responsibility, Intialize the Application
        /*Commented for bug 5233870*/
        -- Un Commented for bug 8464143.
        PA_WORKFLOW_UTILS.Set_Global_Attr (p_item_type   => itemtype,
                                           p_item_key    => itemkey,
                                           p_err_code    => l_err_code);


        -- R12 MOAC, 19-JUL-05, jwhite -------------------
        -- Set Single Project/OU context

        PA_BUDGET_UTILS.Set_Prj_Policy_Context (
            p_project_id      => V_PROJECT_ID,
            x_return_status   => l_return_status,
            x_msg_count       => l_msg_count,
            x_msg_data        => l_msg_data,
            x_err_code        => l_err_code);

        IF (l_err_code <> 0)
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- -----------------------------------------------
        -- Changes By BT Technology Team on 06-MAR-2015--
        -- -- the following code is commented out (on 06-Mar-2015 following a RIDD raised by A2R Team) to dynamically fetch the threshold amount based on project type
        --so that in case a new project type gets added the threshold amount for that type can be configured using a lookup value---
        /* IF V_PROJECT_TYPE LIKE 'IT%'
         THEN
            V_PROFILE_NAME := 'XXDO_IT_PROJECT_BUDGET_APPROVAL_THRESHOLD';
         ELSIF UPPER (V_PROJECT_TYPE) LIKE UPPER ('Retail%')
         THEN
            V_PROFILE_NAME := 'XXDO_RETAIL_PROJECT_BUDGET_APPROVAL_THRESHOLD';
         ELSIF UPPER (V_PROJECT_TYPE) LIKE UPPER ('Supply Chain%')
         THEN
            V_PROFILE_NAME :=
               'XXDO_SUPPLY_CHAIN_PROJECT_BUDGET_APPROVAL_THRESHOLD';
         END IF;*/
        -- retreiving the budget amount threshold from the lookup,this will return the amount threshold depending on the project type---
        -- Added By BT Technology Team on 06-MAR-2015--
        SELECT segment_value
          INTO v_level_value
          FROM pa_segment_value_lookup_sets x, pa_segment_value_lookups y
         WHERE     x.segment_value_lookup_set_id =
                   y.segment_value_lookup_set_id
               AND x.segment_value_lookup_set_name =
                   'XXDO_PROJ_TYPE_BUD_AMT_THHOLD'
               AND UPPER (y.segment_value_lookup) = UPPER (V_PROJECT_TYPE)
               AND ROWNUM = 1;



        SELECT COUNT (BUDGET_VERSION_ID)
          INTO V_VERSION_NUMBER
          FROM apps.pa_budget_versions
         WHERE BUDGET_TYPE_CODE = 'Cost Budget' AND PROJECT_ID = V_PROJECT_ID;



        /*SELECT fpov.level_value
        into v_level_value
        from apps.fnd_profile_options_vl  fpo,
        apps.FND_PROFILE_OPTION_VALUES  fpov
        where fpo.user_profile_option_name = V_PROFILE_NAME
        and fpo.profile_option_id = fpov.profile_option_id;*/
        ---   v_level_value := FND_PROFILE.VALUE (V_PROFILE_NAME);

        --the following query retrieves the global FP&A owner depending on the respective project type from the lookup---
        SELECT segment_value
          INTO l_ROLE
          FROM pa_segment_value_lookup_sets x, pa_segment_value_lookups y
         WHERE     x.segment_value_lookup_set_id =
                   y.segment_value_lookup_set_id
               AND x.segment_value_lookup_set_name =
                   'XXDO_PROJ_TYPE_BUD_APP_MAP_L2'
               AND UPPER (y.segment_value_lookup) = UPPER (V_PROJECT_TYPE)
               AND ROWNUM = 1;


        IF (V_VERSION_NUMBER > 1 OR V_TOTAL_BURDENED_COST > v_level_value)
        THEN
            OPEN C_GET_OWNERS (l_role);

            FETCH C_GET_OWNERS INTO V_GLOBAL_FPA_user_id, V_GLOBAL_FPA_user_name, V_GLOBAL_FPA_full_name;

            IF (C_GET_OWNERS%FOUND)
            THEN
                CLOSE C_GET_OWNERS;

                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_FPA_ID'
                                           , avalue => V_GLOBAL_FPA_user_id);

                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_FPA_USERNAME'
                                           , avalue => V_GLOBAL_FPA_user_name);

                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => 'XXDO_GLOBAL_FPA_FULLNAME'
                                           , avalue => V_GLOBAL_FPA_full_name);


                wf_engine.SetItemAttrText (
                    itemtype   => itemtype,
                    itemkey    => itemkey,
                    aname      => 'XXDO_TIMEOUT_L2',
                    avalue     =>
                        FND_PROFILE.VALUE (
                            'XXDO_PA_BUDGET_NOTIFICATION_TIMEOUT_L2'));



                wf_engine.SetItemAttrText (
                    itemtype   => itemtype,
                    itemkey    => itemkey,
                    aname      => 'XXDO_LOOP_COUNT_L2',
                    avalue     =>
                        FND_PROFILE.VALUE (
                            'XXDO_PA_BUDGET_NOTIFICATION_LOOP_COUNT_L2'));


                wf_engine.SetItemAttrText (
                    itemtype   => itemtype,
                    itemkey    => itemkey,
                    aname      => 'XXDO_MSG_FPA_NAME',
                    avalue     =>
                           'and "'
                        || V_GLOBAL_FPA_full_name
                        || '" ('
                        || V_GLOBAL_FPA_user_name
                        || ')');

                l_approver_role   :=
                       'APPR_'
                    || itemtype
                    || itemkey
                    || TO_CHAR (SYSDATE, 'Jsssss')
                    || 'FPA';

                WF_DIRECTORY.CreateAdHocRole (
                    role_name           => l_approver_role,
                    role_display_name   => V_GLOBAL_FPA_full_name,
                    expiration_date     => SYSDATE + 1);

                wf_engine.SetItemAttrText (itemtype => itemtype, itemkey => itemkey, aname => '#FROM_ROLE'
                                           , avalue => l_approver_role);

                V_DOCUMENT_ID   :=
                    'PLSQL:xxdo_budget_wf.XX_create_DOC_WF/' || ITEMKEY;

                wf_engine.setitemattrtext (itemtype => itemtype, itemkey => itemkey, ANAME => '#HISTORY'
                                           , avalue => V_DOCUMENT_ID);

                resultout   := wf_engine.eng_completed || ':' || 'YES';
            ELSE
                CLOSE C_GET_OWNERS;

                resultout   := wf_engine.eng_completed || ':' || 'NO';
            END IF;
        ELSE
            resultout   := wf_engine.eng_completed || ':' || 'NA';
            NULL;
        END IF;
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'FPA_APPROVAL_REQUIRED', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
        WHEN OTHERS
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'FPA_APPROVAL_REQUIRED', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END;

    PROCEDURE SET_ACTION_HISTORY (itemtype    IN            VARCHAR2,
                                  itemkey     IN            VARCHAR2,
                                  actid       IN            NUMBER,
                                  funcmode    IN            VARCHAR2,
                                  resultout      OUT NOCOPY VARCHAR2)
    IS
        V_DOCUMENT_ID   CLOB;
    BEGIN
        V_DOCUMENT_ID   :=
            'PLSQL:xxdo_budget_wf.XX_create_DOC_WF/' || ITEMKEY;

        wf_engine.setitemattrtext (itemtype => itemtype, itemkey => itemkey, ANAME => '#HISTORY'
                                   , avalue => V_DOCUMENT_ID);
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'FPA_APPROVAL_REQUIRED', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
        WHEN OTHERS
        THEN
            WF_CORE.CONTEXT ('PA_BUDGET_WF', 'FPA_APPROVAL_REQUIRED', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END;

    PROCEDURE XX_create_DOC_WF (document_id IN VARCHAR2, DISPLAY_TYPE IN VARCHAR2, DOCUMENT IN OUT NOCOPY CLOB
                                , document_type IN OUT NOCOPY VARCHAR2)
    IS
        lv_details               CLOB;
        V_ITEMKEY                VARCHAR2 (100) := document_id;

        CURSOR CUR_ACTION_HOSTORY IS
            SELECT wfi.activity_result_code, wfi.end_date, wfn.from_user,
                   wfn.to_user
              FROM wf_item_activity_statuses wfi, wf_notifications wfn
             WHERE     wfi.item_key = V_ITEMKEY
                   AND wfi.item_type = 'PABUDWF'
                   AND wfi.notification_id = wfn.notification_id;

        CUR_ACTION_HOSTORY_REC   CUR_ACTION_HOSTORY%ROWTYPE;
        V_SEQ_NUM                NUMBER := 1;
    BEGIN
        /* TABLE HEADER*/
        lv_details      :=
               lv_details
            || '<h4>'
            || 'Action History'
            || '</H4>'
            || '<table border = ?1?> <tr>'
            || '<th>'
            || 'Num'
            || '</th>'
            || '<th>'
            || 'Action Date'
            || '</th>'
            || '<th>'
            || 'Action'
            || '</th>'
            || '<th>'
            || 'From'
            || '</th>'
            || '<th>'
            || 'To'
            || '</th>';

        FOR CUR_ACTION_HOSTORY_REC IN CUR_ACTION_HOSTORY
        LOOP
            /*TABLE BODY */
            lv_details   :=
                   lv_details
                || '<tr>'
                || '<td>'
                || V_SEQ_NUM
                || '</td>'
                || '<td>'
                || CUR_ACTION_HOSTORY_REC.end_date
                || '</td>'
                || '<td>'
                || CUR_ACTION_HOSTORY_REC.activity_result_code
                || '</td>'
                || '<td>'
                || CUR_ACTION_HOSTORY_REC.from_user
                || '</td>'
                || '<td>'
                || CUR_ACTION_HOSTORY_REC.TO_user
                || '</td>'
                || '</tr>';

            V_SEQ_NUM   := V_SEQ_NUM + 1;
        END LOOP;

        document        := LV_DETAILS;

        document_type   := 'text/html';
    EXCEPTION
        WHEN OTHERS
        THEN
            document   := '<H4>Error' || SQLERRM || '</H4>';
    END;
END xxdo_budget_wf;
/
