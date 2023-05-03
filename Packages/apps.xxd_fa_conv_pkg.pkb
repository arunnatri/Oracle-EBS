--
-- XXD_FA_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_CONV_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FA_CONV_PKG
    * Author       : BT Technology Team
    * Created      : 07-JUL-2014
    * Program Name : XXD FA Conversion - Extract, Validate and Load Program
    * Description  : This package contains procedures and functions to extract, validate and
    *                load data to interface table for FA Conversion.
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created package body script for FA Conversion
    ****************************************************************************************/
    --Start comment as Deckers Fixed Asset Conversion Program,Deckers Fixed Asset Load Conversion Program,Deckers Fixed Asset Validate Conversion Program not required
    /* PROCEDURE print_log_prc (p_message IN VARCHAR2)
     IS*/
    /****************************************************************************************
    * Procedure : print_log_prc
    * Synopsis  : This Procedure shall write to the concurrent program log file
    * Design    : Program input debug flag is 'Y' then the procedure shall write the message
    *             input to concurrent program log file
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /* BEGIN
        --print log in log file if input parameter Debug Flag is 'Y'
        IF gc_debug_flag = 'Y'
        THEN
           apps.fnd_file.put_line (apps.fnd_file.LOG, p_message);
        END IF;
     END print_log_prc;

     PROCEDURE extract_records_prc (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2)
     IS*/
    /****************************************************************************************
    * Procedure : extract_records_prc
    * Synopsis  : This Procedure populates staging table xxd_fa_conv_stg_t
    * Design    : Program populates staging table xxd_fa_conv_stg_t with view data
    *             xxd_fa_conv_stg_v connecting to 12.0.6 instance through DB Link
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    -- Cursor to fetch records for staging table
    /* CURSOR xxd_fa_conv_stg_c
     IS
        SELECT asset_number, asset_description, book_type_code,
               cat_segment1, cat_segment2, cat_segment3, units, asset_cost,
               loc_segment1, loc_segment2, loc_segment3, loc_segment4,
               loc_segment5, loc_segment6, loc_segment7,
               depreciation_expense_account, asset_clearing_account, dpis,
               depreciation_reserve, ytd_depreciation, life_in_months,
               depreciation_method, depreciate_flag
          FROM xxd_fa_conv_stg_v;

     l_rec_count         NUMBER := 0;
     l_total_rec_count   NUMBER := 0;
  BEGIN
     print_log_prc ('xxd_fa_conv_pkg.extract_records_prc Begin');

     DELETE      xxd_fa_conv_stg_t;

     print_log_prc (   'No. of rows deleted from xxd_fa_conv_stg_t: '
                    || SQL%ROWCOUNT
                   );
     COMMIT;

     FOR lcu_xxd_fa_conv_stg_rec IN xxd_fa_conv_stg_c
     LOOP
        l_total_rec_count := l_total_rec_count + 1;

        BEGIN
           -- insert records to staging table
           INSERT INTO xxd_fa_conv_stg_t
                       (record_id, batch_number, record_status,
                        asset_number,
                        asset_description,
                        book_type_code, asset_category_id,
                        cat_segment1,
                        cat_segment2,
                        cat_segment3,
                        units,
                        asset_cost, location_id,
                        loc_segment1,
                        loc_segment2,
                        loc_segment3,
                        loc_segment4,
                        loc_segment5,
                        loc_segment6,
                        loc_segment7, expense_code_combination_id,
                        depreciation_expense_account,
                        payables_code_combination_id,
                        asset_clearing_account,
                        date_placed_in_service,
                        deprn_reserve,
                        ytd_deprn,
                        deprn_method_code,
                        life_in_months, amortization_start_date,
                        amortize_nbv_flag, depreciate_flag,
                        orig_date_placed_in_service, error_message,
                        request_id, created_by, creation_date,
                        last_updated_by, last_update_date,
                        last_update_login, stg_attribute1, stg_attribute2,
                        stg_attribute3, stg_attribute4, stg_attribute5,
                        stg_attribute6, stg_attribute7, stg_attribute8,
                        stg_attribute9, stg_attribute10, stg_attribute11,
                        stg_attribute12, stg_attribute13, stg_attribute14,
                        stg_attribute15, mass_addition_id, file_name
                       )
                VALUES (xxd_fa_conv_stg_seq.NEXTVAL,              --record_id
                                                    NULL,      --batch_number
                                                         'N', --record_status
                        lcu_xxd_fa_conv_stg_rec.asset_number,
                        lcu_xxd_fa_conv_stg_rec.asset_description,
                        lcu_xxd_fa_conv_stg_rec.book_type_code, NULL,
                        lcu_xxd_fa_conv_stg_rec.cat_segment1,
                        lcu_xxd_fa_conv_stg_rec.cat_segment2,
                        lcu_xxd_fa_conv_stg_rec.cat_segment3,
                        lcu_xxd_fa_conv_stg_rec.units,
                        lcu_xxd_fa_conv_stg_rec.asset_cost, NULL,
                        lcu_xxd_fa_conv_stg_rec.loc_segment1,
                        lcu_xxd_fa_conv_stg_rec.loc_segment2,
                        lcu_xxd_fa_conv_stg_rec.loc_segment3,
                        lcu_xxd_fa_conv_stg_rec.loc_segment4,
                        lcu_xxd_fa_conv_stg_rec.loc_segment5,
                        lcu_xxd_fa_conv_stg_rec.loc_segment6,
                        lcu_xxd_fa_conv_stg_rec.loc_segment7, NULL,
                        lcu_xxd_fa_conv_stg_rec.depreciation_expense_account,
                        NULL,
                        lcu_xxd_fa_conv_stg_rec.asset_clearing_account,
                        lcu_xxd_fa_conv_stg_rec.dpis,
                        lcu_xxd_fa_conv_stg_rec.depreciation_reserve,
                        lcu_xxd_fa_conv_stg_rec.ytd_depreciation,
                        lcu_xxd_fa_conv_stg_rec.depreciation_method,
                        lcu_xxd_fa_conv_stg_rec.life_in_months, NULL,
                        NULL, lcu_xxd_fa_conv_stg_rec.depreciate_flag,
                        lcu_xxd_fa_conv_stg_rec.dpis, NULL,
                        gn_conc_request_id, gn_user_id, gd_sys_date,
                        gn_user_id, gd_sys_date,
                        gn_login_id, NULL, NULL,
                        NULL, NULL, NULL,
                        NULL, NULL, NULL,
                        NULL, NULL, NULL,
                        NULL, NULL, NULL,
                        NULL, NULL, NULL
                       );

           l_rec_count := l_rec_count + 1;
        EXCEPTION
           WHEN OTHERS
           THEN
              xxd_common_utils.record_error
                 (p_module          => gc_fa_module,
                  p_org_id          => gn_org_id,
                  p_program         => gc_program_name,
                  p_error_msg       =>    'Error while inserting into xxd_item_conv_stg_seq: '
                                       || SQLERRM,
                  p_error_line      => DBMS_UTILITY.format_error_backtrace,
                  p_created_by      => gn_user_id,
                  p_request_id      => gn_conc_request_id
                 );
        END;
     END LOOP;

     print_log_prc ('No. of records found: ' || l_total_rec_count);
     print_log_prc (   'No. of records inserted in xxd_fa_conv_stg_t: '
                    || l_rec_count
                   );
     COMMIT;
     print_log_prc ('xxd_fa_conv_pkg.extract_records_prc End');
  EXCEPTION
     WHEN OTHERS
     THEN
        IF xxd_fa_conv_stg_c%ISOPEN
        THEN
           CLOSE xxd_fa_conv_stg_c;
        END IF;

        print_log_prc (   'Error in xxd_fa_conv_pkg.extract_records_prc: '
                       || SQLERRM
                      );
        xxd_common_utils.record_error
           (p_module          => gc_fa_module,
            p_org_id          => gn_org_id,
            p_program         => gc_program_name,
            p_error_msg       =>    'Error in xxd_fa_conv_pkg.extract_records_prc: '
                                 || SQLERRM,
            p_error_line      => DBMS_UTILITY.format_error_backtrace,
            p_created_by      => gn_user_id,
            p_request_id      => gn_conc_request_id
           );
  END extract_records_prc;

  PROCEDURE create_batch_prc (
     x_retcode      OUT      NUMBER,
     x_errbuff      OUT      VARCHAR2,
     p_batch_size   IN       NUMBER
  )
  AS*/
    /****************************************************************************************
    * Procedure : create_batch_prc
    * Synopsis  : This Procedure updates batch_number in staging table xxd_fa_conv_stg_t
    * Design    : Program updates batch_number in staging table xxd_fa_conv_stg_t with based
    *             on input parameter p_batch_size
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /* Variable Declaration*/
    /*   ln_count          NUMBER;
       ln_batch_count    NUMBER;
       ln_batch_number   NUMBER;
       ln_first_rec      NUMBER;
       ln_last_rec       NUMBER;
       ln_end_rec        NUMBER;
    BEGIN
       print_log_prc ('xxd_fa_conv_pkg.create_batch_prc Begin');
       ln_count := 0;
       ln_batch_count := 1;
       ln_first_rec := 1;
       ln_last_rec := 1;
       ln_end_rec := 1;

       SELECT COUNT (record_id), MIN (record_id), MAX (record_id)
         INTO ln_count, ln_first_rec, ln_last_rec
         FROM xxd_fa_conv_stg_t
        WHERE record_status = 'N' AND batch_number IS NULL;

       -- Caluclating batch count
       SELECT CEIL (ln_count / p_batch_size)
         INTO ln_batch_count
         FROM DUAL;

       IF ln_batch_count < 0
       THEN
          ln_batch_count := 1;
       END IF;

       FOR ln_batch IN 1 .. ln_batch_count
       LOOP
          IF ln_batch <> 1
          THEN
             ln_first_rec := ln_first_rec + p_batch_size;
          END IF;

          ln_end_rec := (ln_first_rec + (p_batch_size - 1));

          IF ln_batch = ln_batch_count
          THEN
             ln_end_rec := ln_last_rec;
          END IF;

          ln_batch_number := xxd_fa_conv_batch_seq.NEXTVAL;

          BEGIN
             --Updating batch number for processing
             UPDATE xxd_fa_conv_stg_t
                SET batch_number = ln_batch_number,
                    last_update_date = gd_sys_date,
                    last_updated_by = gn_user_id,
                    request_id = gn_conc_request_id
              WHERE record_status = 'N'
                AND batch_number IS NULL
                AND record_id BETWEEN ln_first_rec AND ln_end_rec;

             COMMIT;
          EXCEPTION
             WHEN OTHERS
             THEN
                print_log_prc ('Error while updating batch_number: ' || SQLERRM
                              );
                xxd_common_utils.record_error
                      (p_module          => gc_fa_module,
                       p_org_id          => gn_org_id,
                       p_program         => gc_program_name,
                       p_error_msg       =>    'Error while updating batch_number: '
                                            || SQLERRM,
                       p_error_line      => DBMS_UTILITY.format_error_backtrace,
                       p_created_by      => gn_user_id,
                       p_request_id      => gn_conc_request_id
                      );
          END;
       END LOOP;

       print_log_prc ('xxd_fa_conv_pkg.create_batch_prc End');
    EXCEPTION
       WHEN OTHERS
       THEN
          print_log_prc (   'Error in xxd_fa_conv_pkg.create_batch_prc: '
                         || SQLERRM
                        );
          xxd_common_utils.record_error
              (p_module          => gc_fa_module,
               p_org_id          => gn_org_id,
               p_program         => gc_program_name,
               p_error_msg       =>    'Error in xxd_fa_conv_pkg.create_batch_prc: '
                                    || SQLERRM,
               p_error_line      => DBMS_UTILITY.format_error_backtrace,
               p_created_by      => gn_user_id,
               p_request_id      => gn_conc_request_id
              );
    END create_batch_prc;

    PROCEDURE val_load_main_prc (
       x_retcode      OUT      NUMBER,
       x_errbuff      OUT      VARCHAR2,
       p_process      IN       VARCHAR2,
       p_batch_size   IN       NUMBER,
       p_debug        IN       VARCHAR2
    )
    AS*/
    /****************************************************************************************
    * Procedure : val_load_main_prc
    * Synopsis  : This Procedure is called by FA Conversion Concurrent Program
    * Design    : Program calls procedure based on input parameter p_process to Extract,
    *             Validate or Load data for Converstion
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /* Variable Declaration*/
    /*  ln_eligible_records           NUMBER;
      ln_total_valid_records        NUMBER;
      ln_total_error_records        NUMBER;
      ln_total_load_records         NUMBER;
      ln_batch_low                  NUMBER;
      ln_total_batch                NUMBER;
      l_request_id                  NUMBER;
      l_phase                       VARCHAR2 (100);
      l_status                      VARCHAR2 (100);
      l_dev_phase                   VARCHAR2 (100);
      l_dev_status                  VARCHAR2 (100);
      l_messase                     VARCHAR2 (100);
      l_wait_for_request            BOOLEAN        := FALSE;
      l_get_request_status          BOOLEAN        := FALSE;
      request_submission_failed     EXCEPTION;
      request_completion_abnormal   EXCEPTION;
   BEGIN
      -----------  To Initialize APPS ----------
      gc_debug_flag := p_debug;
      print_log_prc ('xxd_fa_conv_pkg.val_load_main_prc Begin');
      fnd_global.apps_initialize (gn_user_id,
                                  fnd_global.resp_id,
                                  fnd_global.resp_appl_id
                                 );
      l_request_id := NULL;

      IF p_process = 'EXTRACT'
      THEN
         print_log_prc ('Extracting data to load to staging table');
         gc_program_name := 'Deckers Fixed Asset Conversion Program';
         -- Call extract_records_prc procedure to load data to staging table
         extract_records_prc (x_retcode      => x_retcode,
                              x_errbuff      => x_errbuff);
      ELSIF p_process = 'VALIDATE'
      THEN
         print_log_prc ('Validate data in staging table');
         ln_eligible_records := 0;
         ln_batch_low := 0;
         ln_total_batch := 0;
         ln_total_valid_records := 0;
         ln_total_error_records := 0;
         fnd_file.put_line (fnd_file.LOG, 'Test1');

         SELECT COUNT (*)
           INTO ln_eligible_records
           FROM xxd_fa_conv_stg_t
          WHERE record_status IN ('N', 'E');

         fnd_file.put_line (fnd_file.LOG, 'Test2');

         IF ln_eligible_records > 0
         THEN
            -- Call create_batch_prc procedure to update batch number in
            -- staging table
            create_batch_prc (x_retcode, x_errbuff, p_batch_size);

            SELECT MAX (batch_number)
              INTO ln_total_batch
              FROM xxd_fa_conv_stg_t
             WHERE record_status IN ('N', 'E');

            SELECT MIN (batch_number)
              INTO ln_batch_low
              FROM xxd_fa_conv_stg_t
             WHERE record_status IN ('N', 'E');

            fnd_file.put_line (fnd_file.LOG, 'Test3');
            fnd_file.put_line (fnd_file.LOG,
                               'ln_total_batch ' || ln_total_batch
                              );
            fnd_file.put_line (fnd_file.LOG, 'ln_batch_low ' || ln_batch_low);

            FOR ln_batch IN ln_batch_low .. ln_total_batch
            LOOP
               fnd_file.put_line (fnd_file.LOG, 'Test31');

               BEGIN
                  -- Submit child requests for Validating records in
                  -- staging table
                  l_request_id :=
                     fnd_request.submit_request
                                          (application      => 'XXDCONV',
                                           program          => 'XXD_FA_VALIDATE_CONV',
                                           argument1        => ln_batch,
                                           argument2        => ln_batch,
                                           argument3        => gc_debug_flag
                                          );
                  fnd_file.put_line (fnd_file.LOG, 'Test32');
                  COMMIT;
                  fnd_file.put_line (fnd_file.LOG, 'Test4');

                  IF l_request_id > 0
                  THEN
                     --Waits for the Child requests completion
                     l_wait_for_request :=
                        fnd_concurrent.wait_for_request
                                                 (request_id      => l_request_id,
                                                  INTERVAL        => 60,
                                                  max_wait        => 0,
                                                  phase           => l_phase,
                                                  status          => l_status,
                                                  dev_phase       => l_dev_phase,
                                                  dev_status      => l_dev_status,
                                                  MESSAGE         => l_messase
                                                 );
                     COMMIT;
                     -- Get the Request Completion Status.
                     l_get_request_status :=
                        fnd_concurrent.get_request_status
                                                  (request_id          => l_request_id,
                                                   appl_shortname      => NULL,
                                                   program             => NULL,
                                                   phase               => l_phase,
                                                   status              => l_status,
                                                   dev_phase           => l_dev_phase,
                                                   dev_status          => l_dev_status,
                                                   MESSAGE             => l_messase
                                                  );

                     --Check the status if it iS completed Normal
                     IF     UPPER (l_dev_phase) != 'COMPLETED'
                        AND UPPER (l_dev_status) != 'NORMAL'
                     THEN
                        RAISE request_completion_abnormal;
                     END IF;
                  ELSE
                     RAISE request_submission_failed;
                  END IF;
               EXCEPTION
                  WHEN request_submission_failed
                  THEN
                     print_log_prc
                          (   'Child Concurrent request submission failed - '
                           || ' XXD_FA_VALIDATE_CONV - '
                           || l_request_id
                           || ' - '
                           || SQLERRM
                          );
                     xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Error in child request XXD_FA_VALIDATE_CONV RID: '
                                              || l_request_id
                                              || SQLERRM,
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
                  WHEN request_completion_abnormal
                  THEN
                     print_log_prc
                                 (   'Submitted request completed with error'
                                  || ' XXD_FA_VALIDATE_CONV - '
                                  || l_request_id
                                 );
                     xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Submitted request completed with error XXD_FA_VALIDATE_CONV RID: '
                                              || l_request_id
                                              || SQLERRM,
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
                  WHEN OTHERS
                  THEN
                     print_log_prc (   'XXD_FA_VALIDATE_CONV ERROR: '
                                    || SUBSTR (SQLERRM, 0, 240)
                                   );
                     xxd_common_utils.record_error
                         (p_module          => gc_fa_module,
                          p_org_id          => gn_org_id,
                          p_program         => gc_program_name,
                          p_error_msg       =>    'XXD_FA_VALIDATE_CONV ERROR: '
                                               || SQLERRM,
                          p_error_line      => DBMS_UTILITY.format_error_backtrace,
                          p_created_by      => gn_user_id,
                          p_request_id      => gn_conc_request_id
                         );
               END;
            END LOOP;

            fnd_file.put_line (fnd_file.LOG, 'Test5');

            SELECT COUNT (*)
              INTO ln_total_valid_records
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'V'
               AND batch_number BETWEEN ln_batch_low AND ln_total_batch;

            SELECT COUNT (*)
              INTO ln_total_error_records
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'E'
               AND batch_number BETWEEN ln_batch_low AND ln_total_batch;

            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output,
                                  RPAD ('S No.    Entity', 50)
                               || RPAD ('Total_Records', 20)
                               || RPAD ('Total_Records_Valid', 20)
                               || RPAD ('Total_Records_Error', 20)
                              );
            fnd_file.put_line
               (fnd_file.output,
                RPAD
                   ('********************************************************************************************************************************',
                    120
                   )
               );
            fnd_file.put_line (fnd_file.output,
                                  RPAD ('1     Fixed Asset', 50)
                               || RPAD (ln_eligible_records, 20)
                               || RPAD (ln_total_valid_records, 20)
                               || RPAD (ln_total_error_records, 20)
                              );
         ELSE
            print_log_prc ('No Eligible Records for Validate Found ');
         END IF;

         error_log_prc;
         print_processing_summary (p_process);
         fnd_file.put_line (fnd_file.LOG, 'Test6');
      ELSIF p_process = 'LOAD'
      THEN
         print_log_prc ('Laod data in staging table to interface table');
         ln_eligible_records := 0;
         ln_batch_low := 0;
         ln_total_batch := 0;
         ln_total_load_records := 0;
         ln_total_error_records := 0;

         SELECT COUNT (*)
           INTO ln_eligible_records
           FROM xxd_fa_conv_stg_t
          WHERE record_status = 'V' AND batch_number IS NOT NULL;

         IF ln_eligible_records > 0
         THEN
            SELECT MAX (batch_number)
              INTO ln_total_batch
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'V' AND batch_number IS NOT NULL;

            SELECT MIN (batch_number)
              INTO ln_batch_low
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'V' AND batch_number IS NOT NULL;

            FOR ln_batch IN ln_batch_low .. ln_total_batch
            LOOP
               BEGIN
                  -- Submit child requests for Loading validated records in
                  -- staging table to interface table
                  l_request_id :=
                     fnd_request.submit_request
                                              (application      => 'XXDCONV',
                                               program          => 'XXD_FA_LOAD_CONV',
                                               argument1        => ln_batch,
                                               argument2        => ln_batch,
                                               argument3        => gc_debug_flag
                                              );
                  COMMIT;

                  IF l_request_id > 0
                  THEN
                     --Waits for the Child requests completion
                     l_wait_for_request :=
                        fnd_concurrent.wait_for_request
                                                 (request_id      => l_request_id,
                                                  INTERVAL        => 60,
                                                  max_wait        => 0,
                                                  phase           => l_phase,
                                                  status          => l_status,
                                                  dev_phase       => l_dev_phase,
                                                  dev_status      => l_dev_status,
                                                  MESSAGE         => l_messase
                                                 );
                     COMMIT;
                     -- Get the Request Completion Status.
                     l_get_request_status :=
                        fnd_concurrent.get_request_status
                                                  (request_id          => l_request_id,
                                                   appl_shortname      => NULL,
                                                   program             => NULL,
                                                   phase               => l_phase,
                                                   status              => l_status,
                                                   dev_phase           => l_dev_phase,
                                                   dev_status          => l_dev_status,
                                                   MESSAGE             => l_messase
                                                  );

                     --Check the status if It IS completed Normal Or Not
                     IF     UPPER (l_dev_phase) != 'COMPLETED'
                        AND UPPER (l_dev_status) != 'NORMAL'
                     THEN
                        RAISE request_completion_abnormal;
                     END IF;
                  ELSE
                     RAISE request_submission_failed;
                  END IF;
               EXCEPTION
                  WHEN request_submission_failed
                  THEN
                     print_log_prc
                          (   'Child Concurrent request submission failed - '
                           || ' XXD_FA_LOAD_CONV - '
                           || l_request_id
                           || ' - '
                           || SQLERRM
                          );
                     xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Child Concurrent request submission failed XXD_FA_VALIDATE_CONV ERROR: '
                                              || l_request_id
                                              || SQLERRM,
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
                  WHEN request_completion_abnormal
                  THEN
                     print_log_prc
                                 (   'Submitted request completed with error'
                                  || ' XXD_FA_LOAD_CONV - '
                                  || l_request_id
                                 );
                     xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Submitted request completed with error XXD_FA_VALIDATE_CONV ERROR: '
                                              || l_request_id
                                              || SQLERRM,
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
                  WHEN OTHERS
                  THEN
                     print_log_prc (   'XXD_FA_LOAD_CONV ERROR:'
                                    || SUBSTR (SQLERRM, 0, 240)
                                   );
                     xxd_common_utils.record_error
                         (p_module          => gc_fa_module,
                          p_org_id          => gn_org_id,
                          p_program         => gc_program_name,
                          p_error_msg       =>    'XXD_FA_LOAD_CONV ERROR: '
                                               || l_request_id
                                               || SQLERRM,
                          p_error_line      => DBMS_UTILITY.format_error_backtrace,
                          p_created_by      => gn_user_id,
                          p_request_id      => gn_conc_request_id
                         );
               END;
            END LOOP;

            SELECT COUNT (*)
              INTO ln_total_load_records
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'V'
               AND batch_number BETWEEN ln_batch_low AND ln_total_batch;

            SELECT COUNT (*)
              INTO ln_total_error_records
              FROM xxd_fa_conv_stg_t
             WHERE record_status = 'E'
               AND batch_number BETWEEN ln_batch_low AND ln_total_batch;

            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line (fnd_file.output,
                                  RPAD ('S No.    Entity', 50)
                               || RPAD ('Total_Records', 20)
                               || RPAD ('Total_Records_Load', 20)
                               || RPAD ('Total_Records_Error', 20)
                              );
            fnd_file.put_line
               (fnd_file.output,
                RPAD
                   ('********************************************************************************************************************************',
                    120
                   )
               );
            fnd_file.put_line (fnd_file.output,
                                  RPAD ('1     Fixed Asset', 50)
                               || RPAD (ln_eligible_records, 20)
                               || RPAD (ln_total_load_records, 20)
                               || RPAD (ln_total_error_records, 20)
                              );
         ELSE
            print_log_prc ('No Eligible Records for Load Found - ' || SQLERRM);
         END IF;

         error_log_prc;
         print_processing_summary (p_process);
      END IF;

      print_log_prc ('xxd_fa_conv_pkg.val_load_main_prc End');
   END val_load_main_prc;

   PROCEDURE validate_records_prc (
      x_retcode      OUT      NUMBER,
      x_errbuff      OUT      VARCHAR2,
      p_batch_low    IN       NUMBER,
      p_batch_high   IN       NUMBER,
      p_debug        IN       VARCHAR2
   )
   AS*/
    /****************************************************************************************
    * Procedure : validate_records_prc
    * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
    * Design    : Procedure validates data for FA conversion
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /* Batch Validate Worker Cursor */
    /* CURSOR fa_val_wrk_cur
     IS
        SELECT *
          FROM xxd_fa_conv_stg_t
         WHERE batch_number BETWEEN p_batch_low AND p_batch_high
           AND record_status IN ('N', 'E');*/

    /* Variable Declaration*/
    /*  l_id_flex_num           NUMBER;
      l_location_id           NUMBER;
      l_record_status         VARCHAR2 (10);
      l_error_message         VARCHAR2 (4000);
      l_category_id           NUMBER;
      l_dep_exp_account       VARCHAR2 (200);
      r12_dep_exp_ccid        NUMBER;
      l_asset_clear_account   VARCHAR2 (200);
      r12_asst_clear_ccid     NUMBER;
      l_asset_id              NUMBER;
      l_period_counter        fa.fa_deprn_periods.period_counter%TYPE;
      l_open_date             DATE;
      l_closed_date           DATE;
      l_dpis                  DATE;
      l_flexerror             VARCHAR2 (1000);
      l_method_id             NUMBER;
      ln_new_concat_segment   VARCHAR2 (311);
      ln_ccid                 NUMBER;                               --Srinivas
   ----------  Accounting Flex field Structure Number -----------
   BEGIN
      print_log_prc ('xxd_fa_conv_pkg.validate_records_prc Beign');
      gc_program_name := 'Deckers Fixed Asset Validate Conversion';
      gn_conc_request_id := fnd_global.conc_request_id;

      FOR fa_valwrk_rec IN fa_val_wrk_cur
      LOOP
         BEGIN
            SELECT id_flex_num
              INTO l_id_flex_num
              FROM fnd_id_flex_structures fls, fa_book_controls fbc
             WHERE fls.id_flex_code = 'GL#'
               AND fbc.accounting_flex_structure = fls.id_flex_num
               AND fbc.book_type_code = fa_valwrk_rec.book_type_code;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_id_flex_num := 0;
               print_log_prc
                  (   'Error in fetching Accounting flex field structure number-'
                   || SQLERRM
                  );
               xxd_common_utils.record_error
                  (p_module          => gc_fa_module,
                   p_org_id          => gn_org_id,
                   p_program         => gc_program_name,
                   p_error_msg       =>    'Error in fetching Accounting flex field structure number for book: '
                                        || fa_valwrk_rec.book_type_code
                                        || ' Error: '
                                        || SQLERRM,
                   p_error_line      => DBMS_UTILITY.format_error_backtrace,
                   p_created_by      => gn_user_id,
                   p_request_id      => gn_conc_request_id
                  );
         END;

         l_location_id := NULL;
         l_record_status := NULL;
         l_error_message := NULL;
         l_category_id := NULL;
         l_period_counter := NULL;
         l_open_date := NULL;
         l_closed_date := NULL;
         l_dpis := NULL;
         l_dep_exp_account := NULL;
         r12_dep_exp_ccid := NULL;
         l_asset_clear_account := NULL;
         r12_asst_clear_ccid := NULL;
         l_asset_id := 0;
         l_flexerror := NULL;
         l_method_id := NULL;

         ---------- Asset Locations -----------
         BEGIN
            SELECT asset_id
              INTO l_asset_id
              FROM fa_additions_b
             WHERE asset_number = fa_valwrk_rec.asset_number
               AND asset_type = 'CAPITALIZED';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_asset_id := 0;
            WHEN OTHERS
            THEN
               l_record_status := 'E';
               l_error_message := 'Error in fetching Asset ID -' || SQLERRM;
               print_log_prc (l_error_message);
         END;

         IF l_asset_id != 0
         THEN
            l_record_status := 'E';
            l_error_message := 'Asset already exists in System';
            print_log_prc (l_error_message);
            xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Asset# '
                                              || fa_valwrk_rec.asset_number
                                              || ' already exists in System',
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
         ELSE
            BEGIN
               -------- Asset Loaction --------
               SELECT location_id
                 INTO l_location_id
                 FROM fa_locations
                WHERE UPPER (segment1) =
                                     TRIM (UPPER (fa_valwrk_rec.loc_segment1))
                  AND UPPER (segment2) =
                                     TRIM (UPPER (fa_valwrk_rec.loc_segment2))
                  AND UPPER (segment3) =
                                     TRIM (UPPER (fa_valwrk_rec.loc_segment3))
                  AND UPPER (segment4) =
                                     TRIM (UPPER (fa_valwrk_rec.loc_segment4))
                  AND UPPER (segment5) =
                                     TRIM (UPPER (fa_valwrk_rec.loc_segment5))
                  --AND UPPER (segment6) = TRIM (UPPER (fa_valwrk_rec.loc_segment6))
                  --AND UPPER (segment7) = TRIM (UPPER (fa_valwrk_rec.loc_segment7))
                  AND enabled_flag = 'Y';
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_record_status := 'E';
                  l_error_message :=
                                 'Error in fetching Location ID -' || SQLERRM;
                  print_log_prc (l_error_message);
                  xxd_common_utils.record_error
                     (p_module          => gc_fa_module,
                      p_org_id          => gn_org_id,
                      p_program         => gc_program_name,
                      p_error_msg       =>    'Error in fetching Location ID for Asset# '
                                           || fa_valwrk_rec.asset_number
                                           || ' Error: '
                                           || SQLERRM,
                      p_error_line      => DBMS_UTILITY.format_error_backtrace,
                      p_created_by      => gn_user_id,
                      p_request_id      => gn_conc_request_id
                     );
            END;

            -------- Asset Categories --------
            BEGIN
               SELECT category_id
                 INTO l_category_id
                 FROM fa_categories_b
                WHERE UPPER (segment1) = UPPER (fa_valwrk_rec.cat_segment1)
                  AND UPPER (segment2) = UPPER (fa_valwrk_rec.cat_segment2)
                  AND UPPER (segment3) = UPPER (fa_valwrk_rec.cat_segment3)
                  AND enabled_flag = 'Y';
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_record_status := 'E';
                  l_error_message :=
                        l_error_message
                     || '\Error in fetching Category ID -'
                     || SQLERRM;
                  print_log_prc (l_error_message);
                  xxd_common_utils.record_error
                     (p_module          => gc_fa_module,
                      p_org_id          => gn_org_id,
                      p_program         => gc_program_name,
                      p_error_msg       =>    'Error in fetching Category ID for Asset# '
                                           || fa_valwrk_rec.asset_number
                                           || ' Error: '
                                           || SQLERRM,
                      p_error_line      => DBMS_UTILITY.format_error_backtrace,
                      p_created_by      => gn_user_id,
                      p_request_id      => gn_conc_request_id
                     );
            END;

            ---------------- FA Methods  ----------------------
            BEGIN
               SELECT method_id
                 INTO l_method_id
                 FROM fa_methods
                WHERE UPPER (method_code) =
                                       UPPER (fa_valwrk_rec.deprn_method_code)
                  AND life_in_months = fa_valwrk_rec.life_in_months;
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_record_status := 'E';
                  l_error_message :=
                        l_error_message
                     || ' LIFE_IN_MONTHS '
                     || fa_valwrk_rec.life_in_months
                     || ' Not defined for method '
                     || fa_valwrk_rec.deprn_method_code
                     || ' - '
                     || SQLERRM;
                  print_log_prc (l_error_message);
                  xxd_common_utils.record_error
                       (p_module          => gc_fa_module,
                        p_org_id          => gn_org_id,
                        p_program         => gc_program_name,
                        p_error_msg       =>    'Error in fetching LIFE_IN_MONTHS '
                                             || fa_valwrk_rec.life_in_months
                                             || ' Not defined for method '
                                             || fa_valwrk_rec.deprn_method_code
                                             || ' -  for Asset# '
                                             || fa_valwrk_rec.asset_number
                                             || ' Error: '
                                             || SQLERRM,
                        p_error_line      => DBMS_UTILITY.format_error_backtrace,
                        p_created_by      => gn_user_id,
                        p_request_id      => gn_conc_request_id
                       );
            END;

            BEGIN
               SELECT period_counter, calendar_period_open_date,
                      NVL (calendar_period_close_date, gd_sys_date)
                 INTO l_period_counter, l_open_date,
                      l_closed_date
                 FROM fa_deprn_periods
                WHERE period_close_date IS NULL
                  AND book_type_code = fa_valwrk_rec.book_type_code;

               IF fa_valwrk_rec.orig_date_placed_in_service BETWEEN l_open_date
                                                                AND l_closed_date
               THEN
                  SELECT MAX (calendar_period_close_date)
                    INTO l_dpis
                    FROM fa_deprn_periods
                   WHERE book_type_code = fa_valwrk_rec.book_type_code
                     AND period_counter < l_period_counter;
               ELSE
                  --l_dpis := fa_valwrk_rec.orig_date_placed_in_service;
                  l_dpis := fa_valwrk_rec.date_placed_in_service;
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_record_status := 'E';
                  l_error_message :=
                        l_error_message
                     || '\Error in fetching date placed in service - '
                     || SQLERRM;
                  print_log_prc (l_error_message);
                  xxd_common_utils.record_error
                     (p_module          => gc_fa_module,
                      p_org_id          => gn_org_id,
                      p_program         => gc_program_name,
                      p_error_msg       =>    'Error in fetching date placed in service for Asset# '
                                           || fa_valwrk_rec.asset_number
                                           || ' Error: '
                                           || SQLERRM,
                      p_error_line      => DBMS_UTILITY.format_error_backtrace,
                      p_created_by      => gn_user_id,
                      p_request_id      => gn_conc_request_id
                     );
            END;

            BEGIN
               r12_dep_exp_ccid := NULL;

               SELECT code_combination_id
                 INTO r12_dep_exp_ccid
                 FROM gl_code_combinations_kfv
                WHERE concatenated_segments =
                                    fa_valwrk_rec.depreciation_expense_account
                  AND NVL (enabled_flag, 'N') = 'Y';
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  r12_dep_exp_ccid :=
                     fnd_flex_ext.get_ccid
                                  ('SQLGL',
                                   'GL#',
                                   l_id_flex_num,
                                   TO_CHAR (gd_sys_date, 'DD-MON-YYYY'),
                                   --fa_valwrk_rec.depreciation_expense_account
                                   fa_valwrk_rec.depreciation_expense_account
                                  );

                  IF r12_dep_exp_ccid = 0
                  THEN
                     l_record_status := 'E';
                     l_flexerror := fnd_message.get;
                     l_error_message :=
                           l_error_message
                        || '\Error in fetching CCID for depreciation expense account -'
                        || fa_valwrk_rec.depreciation_expense_account
                        || ' '
                        || l_flexerror;
                     print_log_prc (l_error_message);
                     xxd_common_utils.record_error
                        (p_module          => gc_fa_module,
                         p_org_id          => gn_org_id,
                         p_program         => gc_program_name,
                         p_error_msg       =>    'Error in fetching CCID for depreciation expense account -'
                                              || fa_valwrk_rec.depreciation_expense_account
                                              || ' '
                                              || l_flexerror
                                              || ' for Asset# '
                                              || fa_valwrk_rec.asset_number,
                         p_error_line      => DBMS_UTILITY.format_error_backtrace,
                         p_created_by      => gn_user_id,
                         p_request_id      => gn_conc_request_id
                        );
                  END IF;
            END;

            IF fa_valwrk_rec.asset_clearing_account IS NOT NULL
            THEN
               BEGIN
                  r12_asst_clear_ccid := NULL;

                  SELECT code_combination_id
                    INTO r12_asst_clear_ccid
                    FROM gl_code_combinations_kfv
                   WHERE concatenated_segments =
                                    fa_valwrk_rec.depreciation_expense_account
                     AND NVL (enabled_flag, 'N') = 'Y';
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     r12_dep_exp_ccid :=
                        fnd_flex_ext.get_ccid
                                  ('SQLGL',
                                   'GL#',
                                   l_id_flex_num,
                                   TO_CHAR (gd_sys_date, 'DD-MON-YYYY'),
                                   --fa_valwrk_rec.depreciation_expense_account
                                   fa_valwrk_rec.depreciation_expense_account
                                  );

                     IF r12_dep_exp_ccid = 0
                     THEN
                        l_record_status := 'E';
                        l_flexerror := fnd_message.get;
                        l_error_message :=
                              l_error_message
                           || '\Error in fetching CCID for depreciation expense account -'
                           || fa_valwrk_rec.depreciation_expense_account
                           || ' '
                           || l_flexerror;
                        print_log_prc (l_error_message);
                        xxd_common_utils.record_error
                           (p_module          => gc_fa_module,
                            p_org_id          => gn_org_id,
                            p_program         => gc_program_name,
                            p_error_msg       =>    'Error in fetching CCID for depreciation expense account -'
                                                 || fa_valwrk_rec.depreciation_expense_account
                                                 || ' '
                                                 || l_flexerror
                                                 || ' for Asset# '
                                                 || fa_valwrk_rec.asset_number,
                            p_error_line      => DBMS_UTILITY.format_error_backtrace,
                            p_created_by      => gn_user_id,
                            p_request_id      => gn_conc_request_id
                           );
                     END IF;
               END;
            END IF;
         END IF;

         --------- Update record status as 'V' ----------
         IF NVL (l_record_status, 'N') = 'E'
         THEN
            UPDATE xxd_fa_conv_stg_t
               SET record_status = 'E',
                   error_message = l_error_message,
                   last_update_date = gd_sys_date,
                   last_updated_by = gn_user_id,
                   request_id = gn_conc_request_id
             WHERE record_id = fa_valwrk_rec.record_id
               AND record_status IN ('N', 'E');
         ELSE
            UPDATE xxd_fa_conv_stg_t
               SET record_status = 'V',
                   error_message = NULL,
                   asset_category_id = l_category_id,
                   location_id = l_location_id,
                   expense_code_combination_id = r12_dep_exp_ccid,
                   payables_code_combination_id = r12_asst_clear_ccid,
                   date_placed_in_service = l_dpis,
                   last_update_date = gd_sys_date,
                   last_updated_by = gn_user_id,
                   request_id = gn_conc_request_id
             WHERE record_id = fa_valwrk_rec.record_id
               AND record_status IN ('N', 'E');
         END IF;

         COMMIT;
      END LOOP;

      print_log_prc ('xxd_fa_conv_pkg.validate_records_prc End');
   EXCEPTION
      WHEN OTHERS
      THEN
         IF fa_val_wrk_cur%ISOPEN
         THEN
            CLOSE fa_val_wrk_cur;
         END IF;
   END validate_records_prc;

   PROCEDURE interface_load_prc (
      x_retcode      OUT      NUMBER,
      x_errbuff      OUT      VARCHAR2,
      p_batch_low    IN       NUMBER,
      p_batch_high   IN       NUMBER,
      p_debug        IN       VARCHAR2
   )
   AS*/
    /****************************************************************************************
    * Procedure : interface_load_prc
    * Synopsis  : This Procedure is called by val_load_main_prc Main procedure
    * Design    : Procedure loads data to interface table for FA conversion
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /* Batch Validate Worker Cursor */
    /*  CURSOR fa_ld_wrk_cur
      IS
         SELECT *
           FROM xxd_fa_conv_stg_t
          WHERE batch_number BETWEEN p_batch_low AND p_batch_high
            AND record_status = 'V';

     -- Variable Declaration
      ln_record_count      NUMBER;
      l_mass_addition_id   NUMBER;
   BEGIN
      print_log_prc ('xxd_fa_conv_pkg.interface_load_prc Begin');
      ln_record_count := 0;
      gc_program_name := 'Deckers Fixed Asset Load Conversion';
      gn_conc_request_id := fnd_global.conc_request_id;

      FOR fa_ldwrk_rec IN fa_ld_wrk_cur
      LOOP
         BEGIN
            SELECT fa_mass_additions_s.NEXTVAL
              INTO l_mass_addition_id
              FROM DUAL;

            INSERT INTO fa_mass_additions
                        (mass_addition_id, asset_number,
                         description, asset_type,
                         book_type_code,
                         asset_category_id,
                         location_id,
                         expense_code_combination_id,
                         payables_code_combination_id,
                         date_placed_in_service,
                         deprn_reserve, ytd_deprn,
                         deprn_method_code,
                         life_in_months,
                         amortization_start_date,
                         amortize_nbv_flag, depreciate_flag, accounting_date,
                         payables_units, payables_cost,
                         fixed_assets_units, fixed_assets_cost,
                         posting_status, queue_name, last_update_login,
                         creation_date, created_by, last_update_date,
                         last_updated_by
                        )
                 VALUES (l_mass_addition_id, fa_ldwrk_rec.asset_number,
                         fa_ldwrk_rec.asset_description, 'CAPITALIZED',
                         -- Asset Type
                         fa_ldwrk_rec.book_type_code,
                         fa_ldwrk_rec.asset_category_id,
                         fa_ldwrk_rec.location_id,
                         fa_ldwrk_rec.expense_code_combination_id,
                         fa_ldwrk_rec.payables_code_combination_id,
                         fa_ldwrk_rec.date_placed_in_service,
                         fa_ldwrk_rec.deprn_reserve,
                                                    --fa_ldwrk_rec.ACCLTED_DEPN,
                                                    fa_ldwrk_rec.ytd_deprn,
                         fa_ldwrk_rec.deprn_method_code,
                         fa_ldwrk_rec.life_in_months,
                         fa_ldwrk_rec.amortization_start_date,
                         fa_ldwrk_rec.amortize_nbv_flag, 'NO', gd_sys_date,
                         fa_ldwrk_rec.units, fa_ldwrk_rec.asset_cost,
                         fa_ldwrk_rec.units, fa_ldwrk_rec.asset_cost,
                         'POST', 'POST', gn_login_id,
                         gd_sys_date, gn_user_id, gd_sys_date,
                         gn_user_id
                        );

            ln_record_count := ln_record_count + 1;

            UPDATE xxd_fa_conv_stg_t
               SET record_status = 'P',
                   mass_addition_id = l_mass_addition_id,
                   last_update_date = gd_sys_date,
                   last_updated_by = gn_user_id,
                   request_id = gn_conc_request_id
             WHERE record_id = fa_ldwrk_rec.record_id AND record_status = 'V';
         --COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               print_log_prc
                         (   'ERROR while inserting into fa_mass_additions: '
                          || SQLERRM
                         );
               xxd_common_utils.record_error
                  (p_module          => gc_fa_module,
                   p_org_id          => gn_org_id,
                   p_program         => gc_program_name,
                   p_error_msg       =>    'ERROR while inserting into fa_mass_additions for Asset# '
                                        || fa_ldwrk_rec.asset_number
                                        || ' Error: '
                                        || SQLERRM,
                   p_error_line      => DBMS_UTILITY.format_error_backtrace,
                   p_created_by      => gn_user_id,
                   p_request_id      => gn_conc_request_id
                  );

               UPDATE xxd_fa_conv_stg_t
                  SET record_status = 'E',
                      error_message =
                            'ERROR while inserting into fa_mass_additions for Asset# '
                         || fa_ldwrk_rec.asset_number,
                      last_update_date = gd_sys_date,
                      last_updated_by = gn_user_id,
                      request_id = gn_conc_request_id
                WHERE record_id = fa_ldwrk_rec.record_id
                  AND record_status = 'V';
         END;

         COMMIT;
      END LOOP;

      print_log_prc (   'Successfully loaded '
                     || ln_record_count
                     || ' records into Interface table'
                    );
      print_log_prc ('xxd_fa_conv_pkg.interface_load_prc End');
   END interface_load_prc;

   PROCEDURE error_log_prc
   IS*/
    /****************************************************************************************
    * Procedure : error_log_prc
    * Synopsis  : This Procedure updates date_placed_in_service in FA_ADDITIONS table
    * Design    : Procedure loads updates date_placed_in_service in FA_ADDITIONS table
    * Notes     :
    * Return Values: None
    * Modification :
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 07-JUL-2014   BT Technology Team         1.00       Created
    ****************************************************************************************/
    /*    CURSOR xxd_fa_conv_stg_err_c
        IS
           SELECT a.*
             FROM xxd_fa_conv_stg_t a
            WHERE a.record_status = 'E';

        cnt   NUMBER := 0;
     BEGIN
        print_log_prc ('xxd_fa_conv_pkg.error_log_prc Begin');
        print_log_prc ('');
        print_log_prc (   RPAD ('S.NO', 10)
                       || RPAD ('RECORD_ID', 10)
                       || RPAD ('ASSET_NUMBER', 100)
                       || RPAD ('BOOK_TYPE', 50)
                       || 'ERROR_MESSAGE'
                      );
        print_log_prc
           ('**********************************************************************************************'
           );

        FOR lcu_xxd_fa_conv_stg_err_rec IN xxd_fa_conv_stg_err_c
        LOOP
           cnt := cnt + 1;
           print_log_prc (   RPAD (cnt, 10)
                          || RPAD (lcu_xxd_fa_conv_stg_err_rec.record_id, 10)
                          || RPAD (lcu_xxd_fa_conv_stg_err_rec.asset_number,
                                   100)
                          || RPAD (lcu_xxd_fa_conv_stg_err_rec.book_type_code,
                                   50
                                  )
                          || lcu_xxd_fa_conv_stg_err_rec.error_message
                         );
        END LOOP;

        print_log_prc ('xxd_fa_conv_pkg.error_log_prc End');
     EXCEPTION
        WHEN OTHERS
        THEN
           IF xxd_fa_conv_stg_err_c%ISOPEN
           THEN
              CLOSE xxd_fa_conv_stg_err_c;
           END IF;
     END error_log_prc;

     PROCEDURE print_processing_summary (p_mode IN VARCHAR2)
     IS
        -- FA Count
        ln_process_cnt    NUMBER := 0;
        ln_error_cnt      NUMBER := 0;
        ln_validate_cnt   NUMBER := 0;
        ln_total          NUMBER := 0;
        ln_cnt            NUMBER := 0;
     BEGIN
        --x_ret_code := gn_suc_const;

        ---------------------------------------------------------------
  --Fetch the summary details from the staging table
  ----------------------------------------------------------------
        fnd_file.put_line (fnd_file.LOG,
                           'gn_conc_request_id ' || gn_conc_request_id
                          );

        SELECT COUNT (DECODE (record_status, 'P', 'P')),
               COUNT (DECODE (record_status, 'E', 'E')),
               COUNT (DECODE (record_status, 'V', 'V')), COUNT (1)
          INTO ln_process_cnt,
               ln_error_cnt,
               ln_validate_cnt, ln_total
          FROM xxd_fa_conv_stg_t;

        --WHERE request_id = gn_conc_request_id;
        fnd_file.put_line
           (fnd_file.output,
            '*************************************************************************************'
           );
        fnd_file.put_line
           (fnd_file.output,
            '************************Summary Report***********************************************'
           );
        fnd_file.put_line
           (fnd_file.output,
            '*************************************************************************************'
           );
        fnd_file.put_line (fnd_file.output, '  ');
        fnd_file.put_line (fnd_file.output,
                              'Total number of FA Records to '
                           || p_mode
                           || '                            : '
                           || ln_total
                          );
        fnd_file.put_line
           (fnd_file.output,
               'Total number of FA Records Successfully Validated                     : '
            || ln_validate_cnt
           );
        fnd_file.put_line
           (fnd_file.output,
               'Total number of FA Records Successfully Processed                     : '
            || ln_process_cnt
           );
        fnd_file.put_line
           (fnd_file.output,
               'Total number of FA Records In Error                                   : '
            || ln_error_cnt
           );
        fnd_file.put_line
           (fnd_file.output,
            '***************************************************************************************'
           );
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output, '');
        fnd_file.put_line (fnd_file.output,
                              RPAD ('S.NO', 10, ' ')
                           || '  '
                           || RPAD ('RECORD_ID', 10, ' ')
                           || '  '
                           || RPAD ('ASSET_NUMBER', 50, ' ')
                           || '  '
                           || RPAD ('BOOK_TYPE', 50, ' ')
                           || '  '
                           || 'ERROR_MESSAGE'
                          );
        fnd_file.put_line (fnd_file.output,
                              RPAD ('--', 10, '-')
                           || '  '
                           || RPAD ('--', 10, '-')
                           || '  '
                           || RPAD ('--', 50, '-')
                           || '  '
                           || RPAD ('--', 50, '-')
                           || '  '
                           || RPAD ('--', 100, '-')
                          );

        FOR error_in IN (SELECT record_id, asset_number, book_type_code,
                                error_message
                           FROM xxd_fa_conv_stg_t
                          WHERE 1 = 1      --AND request_id = gn_conc_request_id
                            AND record_status = 'E')
        LOOP
           ln_cnt := ln_cnt + 1;
           fnd_file.put_line (fnd_file.output,
                                 RPAD (ln_cnt, 10, ' ')
                              || '  '
                              || RPAD (error_in.record_id, 10, ' ')
                              || '  '
                              || RPAD (error_in.asset_number, 50, ' ')
                              || '  '
                              || RPAD (error_in.book_type_code, 50, ' ')
                              || '  '
                              || RPAD (error_in.error_message, 500, ' ')
                             );
        END LOOP;
     EXCEPTION
        WHEN OTHERS
        THEN
           -- x_ret_code := gn_err_const;
           print_log_prc (   SUBSTR (SQLERRM, 1, 150)
                          || ' Exception in print_processing_summary procedure '
                         );
     END print_processing_summary;*/
    --End comment as Deckers Fixed Asset Conversion Program,Deckers Fixed Asset Load Conversion Program,Deckers Fixed Asset Validate Conversion Program not required
    PROCEDURE update_deprn_flag (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_flag IN VARCHAR2
                                 , p_asset_number IN VARCHAR2)
    IS
        CURSOR get_fa_books_c IS
            SELECT fb.asset_id, fb.book_type_code
              FROM fa_books fb, fa_additions_b fa
             WHERE     fb.asset_id = fa.asset_id
                   AND 1 = 1
                   AND capitalize_flag = 'YES'
                   --AND fb.asset_id = 30157
                   AND asset_number = NVL (p_asset_number, asset_number)
                   AND depreciate_flag <> UPPER (p_flag);

        TYPE asset_depn_flag IS TABLE OF get_fa_books_c%ROWTYPE;

        asset_depn_tbl                asset_depn_flag;
        l_trans_rec                   fa_api_types.trans_rec_type;
        l_asset_hdr_rec               fa_api_types.asset_hdr_rec_type;
        l_asset_fin_rec_adj           fa_api_types.asset_fin_rec_type;
        l_asset_fin_rec_new           fa_api_types.asset_fin_rec_type;
        l_asset_fin_mrc_tbl_new       fa_api_types.asset_fin_tbl_type;
        l_inv_trans_rec               fa_api_types.inv_trans_rec_type;
        l_inv_tbl                     fa_api_types.inv_tbl_type;
        l_inv_rate_tbl                fa_api_types.inv_rate_tbl_type;
        l_asset_deprn_rec_adj         fa_api_types.asset_deprn_rec_type;
        l_asset_deprn_rec_new         fa_api_types.asset_deprn_rec_type;
        l_asset_deprn_mrc_tbl_new     fa_api_types.asset_deprn_tbl_type;
        l_inv_rec                     fa_api_types.inv_rec_type;
        l_group_reclass_options_rec   fa_api_types.group_reclass_options_rec_type;
        l_return_status               VARCHAR2 (1);
        l_mesg_count                  NUMBER;
        l_mesg                        VARCHAR2 (512);
    /*     -- Get the user_id
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = l_user_name;

      -- Get the application_id and responsibility_id
      SELECT application_id, responsibility_id
        INTO l_application_id, l_resp_id
        FROM fnd_responsibility_vl
       WHERE responsibility_name = l_resp_name; */
    BEGIN
        --dbms_output.enable(10000000);
        OPEN get_fa_books_c;

        LOOP
            FETCH get_fa_books_c BULK COLLECT INTO asset_depn_tbl LIMIT 1;

            IF asset_depn_tbl.COUNT > 0
            THEN
                FOR i IN 1 .. asset_depn_tbl.COUNT
                LOOP
                    fa_srvr_msg.init_server_message;
                    -- asset header info
                    l_asset_hdr_rec.asset_id              := asset_depn_tbl (i).asset_id;
                    l_asset_hdr_rec.book_type_code        :=
                        asset_depn_tbl (i).book_type_code;
                    -- fin rec info
                    l_asset_fin_rec_adj.depreciate_flag   := UPPER (p_flag);
                    fa_adjustment_pub.do_adjustment (
                        -- std parameters
                        p_api_version             => 1.0,
                        p_init_msg_list           => fnd_api.g_false,
                        p_commit                  => fnd_api.g_false,
                        p_validation_level        => fnd_api.g_valid_level_full,
                        p_calling_fn              => 'TEST',
                        x_return_status           => l_return_status,
                        x_msg_count               => l_mesg_count,
                        x_msg_data                => l_mesg,
                        -- api parameters
                        px_trans_rec              => l_trans_rec,
                        px_asset_hdr_rec          => l_asset_hdr_rec,
                        p_asset_fin_rec_adj       => l_asset_fin_rec_adj,
                        x_asset_fin_rec_new       => l_asset_fin_rec_new,
                        x_asset_fin_mrc_tbl_new   => l_asset_fin_mrc_tbl_new,
                        px_inv_trans_rec          => l_inv_trans_rec,
                        px_inv_tbl                => l_inv_tbl,
                        p_asset_deprn_rec_adj     => l_asset_deprn_rec_adj,
                        x_asset_deprn_rec_new     => l_asset_deprn_rec_new,
                        x_asset_deprn_mrc_tbl_new   =>
                            l_asset_deprn_mrc_tbl_new,
                        p_group_reclass_options_rec   =>
                            l_group_reclass_options_rec);
                    --dump messages
                    l_mesg_count                          :=
                        fnd_msg_pub.count_msg;
                /*            IF l_mesg_count > 0
                            THEN
                               l_mesg :=
                                     CHR (10)
                                  || SUBSTR (
                                        fnd_msg_pub.get (fnd_msg_pub.G_FIRST,
                                                         fnd_api.G_FALSE),
                                        1,
                                        250);
                               DBMS_OUTPUT.put_line (l_mesg);

                               FOR i IN 1 .. (l_mesg_count - 1)
                               LOOP
                                  l_mesg :=
                                     SUBSTR (
                                        fnd_msg_pub.get (fnd_msg_pub.G_NEXT, fnd_api.G_FALSE),
                                        1,
                                        250);

                                  DBMS_OUTPUT.put_line (l_mesg);
                               END LOOP;

                               fnd_msg_pub.delete_msg ();
                            END IF; */

                /*       IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
                       THEN
                          FOR i IN 1 .. l_mesg_count
                          LOOP
                             l_mesg :=
                                   l_mesg
                                || '-'
                                || SUBSTR (fnd_msg_pub.get (i, fnd_api.G_FALSE),
                                           1,
                                           250);
                          --DBMS_OUTPUT.put_line (l_mesg);
                          END LOOP;

                          --DBMS_OUTPUT.put_line ('FAILURE');
                          fnd_file.put_line (
                             fnd_file.LOG,
                                'Error : '
                             || l_mesg
                             || ' for Assetid '
                             || asset_depn_tbl (i).asset_id);
                       ELSE
                          fnd_file.put_line (
                             fnd_file.LOG,
                                'Depreciation flag is successfully updated for Assetid '
                             || asset_depn_tbl (i).asset_id);
                       END IF; */
                END LOOP;

                asset_depn_tbl.DELETE;
            ELSE
                EXIT;
            END IF;
        END LOOP;

        CLOSE get_fa_books_c;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception Occured :');
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ':' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG,
                               '========================================');
    END;
END xxd_fa_conv_pkg;
/
