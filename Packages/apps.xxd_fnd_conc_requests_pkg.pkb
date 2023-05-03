--
-- XXD_FND_CONC_REQUESTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FND_CONC_REQUESTS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FND_CONC_REQUESTS_PKG
    * Design       : This package will be used for backing up Concurrent Requests table data
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 06-Feb-2019  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_backup_days IN NUMBER
                    , p_purge_days IN NUMBER)
    AS
        CURSOR get_last_backup_date_c IS
            SELECT TO_DATE (MAX (actual_completion_date), 'DD-MON-RRRR')
              FROM xxd_fnd_concurrent_requests;

        CURSOR get_min_date_c IS
            SELECT TO_DATE (MIN (actual_completion_date), 'DD-MON-RRRR')
              FROM fnd_concurrent_requests
             WHERE actual_completion_date IS NOT NULL;

        CURSOR get_requests_c (p_from_date IN DATE, p_to_date IN DATE)
        IS
            SELECT *
              FROM fnd_concurrent_requests
             WHERE     actual_completion_date IS NOT NULL
                   AND TRUNC (actual_completion_date) BETWEEN p_from_date
                                                          AND p_to_date;

        TYPE requests_tbl_typ IS TABLE OF fnd_concurrent_requests%ROWTYPE;

        l_requests_tbl_typ    requests_tbl_typ;
        ln_recount_count      NUMBER := 0;
        ld_last_backup_date   DATE;
        ld_new_backup_date    DATE;
        ld_min_date           DATE;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (fnd_file.LOG, RPAD ('=', 100, '='));

        -- First Time, set the From Date as the MIN Date
        OPEN get_min_date_c;

        FETCH get_min_date_c INTO ld_min_date;

        CLOSE get_min_date_c;

        -- Retrieve the last backup date
        OPEN get_last_backup_date_c;

        FETCH get_last_backup_date_c INTO ld_last_backup_date;

        CLOSE get_last_backup_date_c;

        ld_last_backup_date   := NVL (ld_last_backup_date, ld_min_date);

        fnd_file.put_line (fnd_file.LOG,
                           'Last Backup Date ' || ld_last_backup_date);

        ld_new_backup_date    :=
            TO_DATE (SYSDATE - p_backup_days, 'DD-MON-RRRR');

        fnd_file.put_line (fnd_file.LOG,
                           'New Backup Date ' || ld_new_backup_date);

        IF ld_last_backup_date >= ld_new_backup_date
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Backup has already been completed till '
                || ld_last_backup_date);
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Begin Backup From Date '
                || ld_last_backup_date
                || ' To Date '
                || ld_new_backup_date);


            OPEN get_requests_c (ld_last_backup_date, ld_new_backup_date);

           <<requests>>
            LOOP
                FETCH get_requests_c
                    BULK COLLECT INTO l_requests_tbl_typ
                    LIMIT 2000;

                ln_recount_count   :=
                    ln_recount_count + l_requests_tbl_typ.COUNT;

                EXIT requests WHEN l_requests_tbl_typ.COUNT = 0;

                FORALL ln_index IN 1 .. l_requests_tbl_typ.COUNT
                    INSERT INTO xxd_fnd_concurrent_requests
                         VALUES l_requests_tbl_typ (ln_index);
            END LOOP requests;

            CLOSE get_requests_c;

            IF ln_recount_count = 0
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No Data Found');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Backed up Requests. Count = ' || ln_recount_count);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'End Backup '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        END IF;

        fnd_file.put_line (fnd_file.LOG, RPAD ('=', 100, '='));

        fnd_file.put_line (
            fnd_file.LOG,
               'Begin Purge Requests older than '
            || TO_DATE (SYSDATE - 100, 'DD-Mon-RRRR'));

        DELETE xxd_fnd_concurrent_requests
         WHERE TO_DATE (actual_completion_date, 'DD-Mon-RRRR') =
               TO_DATE (SYSDATE - p_purge_days, 'DD-Mon-RRRR');

        fnd_file.put_line (fnd_file.LOG,
                           'Total Deleted Record Count = ' || SQL%ROWCOUNT);
        fnd_file.put_line (
            fnd_file.LOG,
            'End Purge ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (fnd_file.LOG, RPAD ('=', 100, '='));
        fnd_file.put_line (
            fnd_file.LOG,
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Main Exception = ' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END main;
END xxd_fnd_conc_requests_pkg;
/
