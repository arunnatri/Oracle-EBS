--
-- XXD_PA_PROJ_EXP_INQ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PA_PROJ_EXP_INQ_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_PA_PROJ_EXP_INQ_PKG
    * Description     : This package is used to get Project Invoice Documents
    * Notes           : 1. DATA Template XML Query and PKG Query always maintain SYNC while changes.
    *                 : 2. Pre-fix should maintain SYNC in upload function and calling function.
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 18-JUL-2018  1.0           Aravind Kannuri           Initial Version for CCR0007350
    ************************************************************************************************/

    --To fetch Invoices to upload
    FUNCTION upload_inv_docs
        RETURN BOOLEAN
    IS
        CURSOR get_invoice_dtls_c IS
              SELECT DISTINCT aia.invoice_num, aia.invoice_id
                FROM pa_expenditure_items_all peia, pa_expenditures_all pe, pa_cost_distribution_lines_all pcdl,
                     pa_projects_all ppa, pa_project_types_all pt, pa_tasks pt,
                     ap_invoices_all aia, hr_all_organization_units_tl hou, per_all_people_f papf
               WHERE     peia.project_id = ppa.project_id
                     AND peia.org_id = ppa.org_id
                     AND peia.task_id = pt.task_id
                     AND ppa.project_id = pt.project_id
                     AND ppa.project_type = pt.project_type
                     AND ppa.org_id = pt.org_id
                     AND peia.expenditure_id = pe.expenditure_id
                     AND peia.expenditure_item_id = pcdl.expenditure_item_id
                     AND peia.project_id = pcdl.project_id
                     AND peia.task_id = pcdl.task_id
                     AND peia.org_id = pcdl.org_id
                     AND peia.document_header_id = aia.invoice_id(+)
                     AND pe.incurred_by_person_id = papf.person_id(+)
                     AND peia.expenditure_item_date BETWEEN NVL (
                                                                papf.effective_start_date,
                                                                peia.expenditure_item_date)
                                                        AND NVL (
                                                                papf.effective_end_date,
                                                                peia.expenditure_item_date)
                     AND ppa.org_id = NVL (aia.org_id, ppa.org_id)
                     AND ppa.project_id = NVL (p_proj_id, ppa.project_id)
                     AND ppa.NAME = NVL (p_proj_name, ppa.NAME)
                     AND pt.task_id = NVL (p_task_id, pt.task_id)
                     AND pt.task_name = NVL (p_task_name, pt.task_name)
                     AND ppa.org_id = NVL (p_org_id, ppa.org_id)
                     AND peia.expenditure_item_id =
                         NVL (p_trans_id, peia.expenditure_item_id)
                     AND peia.expenditure_type =
                         NVL (p_expend_type, peia.expenditure_type)
                     AND pcdl.gl_period_name =
                         NVL (p_gl_period, pcdl.gl_period_name)
                     AND NVL (peia.override_to_organization_id,
                              pe.incurred_by_organization_id) =
                         hou.organization_id
                     AND hou.organization_id =
                         NVL (p_expend_org_id, hou.organization_id)
                     AND NVL (papf.employee_number, 'N') =
                         NVL (p_emp_num, NVL (papf.employee_number, 'N'))
                     AND NVL (papf.full_name, 'N') =
                         NVL (p_emp_name, NVL (papf.full_name, 'N'))
                     AND peia.transaction_source =
                         NVL (p_trans_source, peia.transaction_source)
                     AND peia.system_linkage_function =
                         NVL (p_expend_type_class,
                              peia.system_linkage_function)
                     AND TRUNC (peia.expenditure_item_date) BETWEEN NVL (
                                                                        fnd_date.canonical_to_date (
                                                                            p_item_from_date),
                                                                        TRUNC (
                                                                            peia.expenditure_item_date))
                                                                AND NVL (
                                                                        fnd_date.canonical_to_date (
                                                                            p_item_to_date),
                                                                        NVL (
                                                                            fnd_date.canonical_to_date (
                                                                                p_item_from_date),
                                                                            TRUNC (
                                                                                peia.expenditure_item_date)))
                     AND TRUNC (peia.expenditure_item_date) BETWEEN NVL (
                                                                        fnd_date.canonical_to_date (
                                                                            p_exp_end_from_date),
                                                                        TRUNC (
                                                                            peia.expenditure_item_date))
                                                                AND NVL (
                                                                        fnd_date.canonical_to_date (
                                                                            p_exp_end_to_date),
                                                                        NVL (
                                                                            fnd_date.canonical_to_date (
                                                                                p_exp_end_from_date),
                                                                            TRUNC (
                                                                                peia.expenditure_item_date)))
                     AND hou.LANGUAGE = USERENV ('LANG')
            ORDER BY aia.invoice_id;

        get_invoice_dtls_rec   get_invoice_dtls_c%ROWTYPE;
        ln_count               NUMBER := 0;
        lv_upld_result         VARCHAR2 (50) := 'S';
        lv_doc_prefix          VARCHAR2 (100) := NULL;
        lv_param_proj_num      pa_projects_all.segment1%TYPE;
    BEGIN
        --Print Parameters in LOG
        BEGIN
            SELECT segment1
              INTO lv_param_proj_num
              FROM pa_projects_all
             WHERE project_id = p_proj_id AND org_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_param_proj_num   := NULL;
        END;

        fnd_file.put_line (fnd_file.LOG, 'After Report Trigger Starts :');
        fnd_file.put_line (fnd_file.LOG,
                           'p_entity_name => ' || p_entity_name);
        fnd_file.put_line (fnd_file.LOG,
                           'p_proj_num    => ' || lv_param_proj_num);
        fnd_file.put_line (fnd_file.LOG,
                           'p_user_file_path => ' || p_user_file_path);

        FOR get_invoice_dtls_rec IN get_invoice_dtls_c
        LOOP
            ln_count   := get_invoice_dtls_c%ROWCOUNT;

            IF get_invoice_dtls_rec.invoice_id IS NOT NULL
            THEN
                -- Prefix should be same here and also in calling function 'GET_DOC_FILE_PATH'(Data Template)
                lv_doc_prefix   :=
                       REPLACE (fnd_global.user_name, '.', '_')
                    || '_'
                    || get_invoice_dtls_rec.invoice_num
                    || '_';

                --Calling generic procedure to upload Project Invoice documents in XXD_PROJECT_INVOICES
                --lv_doc_prefix : Prefix of Document file to store in directory
                lv_upld_result   :=
                    xxd_fnd_doc_files_pkg.get_doc_files (get_invoice_dtls_rec.invoice_id, 'AP_INVOICES', --Entity Name
                                                                                                         'XXD_PROJECT_INVOICES'
                                                         ,    --Directory Name
                                                           lv_doc_prefix --'Invoices_'
                                                                        );
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'Uploaded Invoice Documents count => ' || ln_count);

        IF lv_upld_result = 'S'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPLOAD_INV_DOCS: ' || SQLERRM);
            RETURN FALSE;
    END upload_inv_docs;


    --To get and display document file path in report
    FUNCTION get_doc_file_path (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, p_user_file_path IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_doc_file_name   dba_directories.directory_path%TYPE := NULL;
    BEGIN
        --p_user_file_path should be '\\corporate.deckers.com\Sites\Goleta\Common\Deckers Enhancement\Invoices\'
        IF p_user_file_path IS NOT NULL AND p_pk1_value_id IS NOT NULL
        THEN
            BEGIN
                  SELECT p_user_file_path || fl.file_name
                    INTO lv_doc_file_name
                    FROM fnd_attached_documents fad, fnd_documents fd, fnd_lobs fl,
                         fnd_document_datatypes fdd
                   WHERE     fad.document_id = fd.document_id
                         AND fd.media_id = fl.file_id
                         AND fd.datatype_id = fdd.datatype_id
                         AND fdd.NAME = 'FILE'
                         AND fad.entity_name =
                             NVL (p_entity_name, 'AP_INVOICES')
                         AND fad.pk1_value = TO_CHAR (p_pk1_value_id)
                         AND fad.seq_num =
                             (SELECT MAX (seq_num)
                                FROM apps.fnd_attached_documents fad1
                               WHERE fad1.pk1_value = TO_CHAR (p_pk1_value_id))
                         AND fdd.LANGUAGE = USERENV ('LANG')
                         AND fl.LANGUAGE = USERENV ('LANG')
                ORDER BY fad.pk1_value;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_doc_file_name   := NULL;
            END;
        ELSE
            lv_doc_file_name   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'get_doc_file_path function parameters are NULL ');
        END IF;

        RETURN lv_doc_file_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPLOAD_INV_DOCS: ' || SQLERRM);
            RETURN NULL;
    END get_doc_file_path;
END xxd_pa_proj_exp_inq_pkg;
/
