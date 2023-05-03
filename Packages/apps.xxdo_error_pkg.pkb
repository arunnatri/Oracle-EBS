--
-- XXDO_ERROR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ERROR_PKG"
AS
    ------------------------------
    -- Declare global variables --
    ------------------------------
    gd_sysdate             DATE := SYSDATE;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_conc_request_id     NUMBER := fnd_global.conc_request_id;
    gv_trace_dir           VARCHAR2 (240)
                               := fnd_profile.VALUE ('XXCMN_TRACE_DIR');
    gt_conc_program_name   fnd_concurrent_programs.concurrent_program_name%TYPE
        := NULL;
    gt_application_id      fnd_concurrent_programs.application_id%TYPE
                               := NULL;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : search_token                                           --
    -- PARAMETERS  : pv_build_msg - Message string              --
    --           pv_token - Token name                     --
    --           pn_srch_begin - Begin search value              --
    --           xn_tok_begin - Output token location value          --
    -- PURPOSE     : This is a private procedure to search token           --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/29/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE search_token (pv_build_msg IN VARCHAR2, pv_token IN VARCHAR2, pn_srch_begin IN NUMBER
                            , xn_tok_begin OUT NOCOPY NUMBER)
    IS
        ln_start                                NUMBER;
        ln_check_pos                            NUMBER;
        ln_char_after_pos                       NUMBER;
        lv_char_after                           NVARCHAR2 (1);
        alphanumeric_underscore_mask   CONSTANT VARCHAR2 (255)
            := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_' ;
    BEGIN
        ln_start   := pn_srch_begin;

        LOOP
            -- Find the ampersand token value in the string.
            -- This signifies a possible token match.
            -- We say possible because the match could be a partial match to
            -- another token name (i.e. VALUE in VALUESET).
            ln_check_pos   := INSTR (pv_build_msg, '&' || pv_token, ln_start);

            IF (ln_check_pos = 0)
            THEN
                -- No more potential token matches exist in string.
                -- Return o for token position
                xn_tok_begin   := 0;
                EXIT;
            END IF;

            -- Insure that match is not '&&' variable indicating an access key
            IF ((ln_check_pos <> 1) AND (SUBSTR (pv_build_msg, ln_check_pos - 1, 1) = '&'))
            THEN
                ln_start   := ln_check_pos + 2;
            ELSE
                -- Determine if the potential match for the token is an EXACT match
                --  or only a partial matc.
                -- Determine if the character following the token match is an
                --  acceptable trailing character for a token (i.e. something
                --  other than an English uppercase alphabetic character,
                --  a number, or an underscore - these indicate the token name
                --  has additional characters)
                -- If so, the token is considered an exact match.
                ln_char_after_pos   := ln_check_pos + LENGTH (pv_token) + 1;
                lv_char_after       :=
                    SUBSTR (pv_build_msg, ln_char_after_pos, 1);

                IF ((INSTR (alphanumeric_underscore_mask, lv_char_after) = 0) OR (ln_char_after_pos > LENGTH (pv_build_msg)))
                THEN
                    xn_tok_begin   := ln_check_pos;
                    EXIT;
                ELSE
                    ln_start   := ln_char_after_pos;
                END IF;
            END IF;
        END LOOP;
    END search_token;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : replace_token_value                                      --
    -- PARAMETERS  : pv_msg - Message string                    --
    --           pv_token - Token name                     --
    --           pv_token_val - Token value                    --
    -- PURPOSE     : This is a private function to replace token with values--
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/29/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    FUNCTION replace_token_value (pv_msg         IN VARCHAR2,
                                  pv_token       IN VARCHAR2,
                                  pv_token_val   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_token_exists   NUMBER;
        lv_token          VARCHAR2 (30);
        lv_build_tmpmsg   VARCHAR2 (4000);
        lv_msg            VARCHAR2 (4000);
        ln_srch_begin     NUMBER;
        ln_tok_begin      NUMBER;
    BEGIN
        -- Check to see if any tokens exist in the error message
        lv_token          := pv_token;
        ln_token_exists   := INSTR (pv_msg, '&' || lv_token);

        /* If the input token isn't found in the message text, */
        /* try the uppercased version of the token name in case */
        /* the caller is (wrongly) passing a mixed case token name */
        /* As of July 99 all tokens in msg text should be */
        /* uppercase. */
        IF (ln_token_exists = 0)
        THEN
            lv_token          := UPPER (lv_token);
            ln_token_exists   := INSTR (pv_msg, '&' || lv_token);
        END IF;

        -- Only process if instances of the token exist in the msg
        IF (ln_token_exists <> 0)
        THEN
            lv_build_tmpmsg   := '';
            ln_srch_begin     := 1;
            lv_msg            := pv_msg;

            LOOP
                search_token (lv_msg, lv_token, ln_srch_begin,
                              ln_tok_begin);

                IF (ln_tok_begin = 0)
                THEN
                    -- No more tokens found in message
                    EXIT;
                END IF;

                -- Build string, replacing token with token value
                lv_build_tmpmsg   :=
                       lv_build_tmpmsg
                    || SUBSTR (lv_msg,
                               ln_srch_begin,
                               ln_tok_begin - ln_srch_begin)
                    || pv_token_val;
                -- Begin next search at the end of the processed token
                --  including ampersand (the +1)
                ln_srch_begin   := ln_tok_begin + LENGTH (lv_token) + 1;
            END LOOP;

            -- No more tokens in message. Concatenate the remainder
            --   of the message.
            lv_build_tmpmsg   :=
                   lv_build_tmpmsg
                || SUBSTR (lv_msg,
                           ln_srch_begin,
                           LENGTH (lv_msg) - ln_srch_begin + 1);
            RETURN lv_build_tmpmsg;
        ELSE
            RETURN pv_msg;
        END IF;
    END replace_token_value;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : set_exception_token                                    --
    -- PARAMETERS  : pv_exception_code - Exception Code for which token is  --
    --                                   to be set                          --
    --           pv_token_name - Token Name to be set                   --
    --           pv_token_value - Token value to be set                 --
    -- PURPOSE     : This procedure will be used to set token for error     --
    --               message                                                --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE set_exception_token (pv_exception_code IN VARCHAR2, pv_token_name IN VARCHAR2, pv_token_value IN VARCHAR2)
    IS
        lt_message         xxdo_errors.error_message%TYPE;
        lv_upd_message     xxdo_errors.error_message%TYPE;
        lv_token_updated   VARCHAR2 (1);
    BEGIN
        lv_token_updated   := 'N';

        ------------------------------------------------------------------------
        -- Check for the exception message already updated with a token value --
        ------------------------------------------------------------------------
        IF (gv_exception_code = pv_exception_code)
        THEN
            lt_message         := gv_msg_string;
            lv_upd_message     :=
                replace_token_value (pv_msg         => lt_message,
                                     pv_token       => pv_token_name,
                                     pv_token_val   => pv_token_value);
            gv_msg_string      := lv_upd_message;
            lv_token_updated   := 'Y';
        END IF;

        IF lv_token_updated = 'N'
        THEN
            BEGIN
                SELECT MESSAGE
                  INTO lt_message
                  FROM xxdo_exception_defns
                 WHERE exception_code = pv_exception_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lt_message   := NULL;
            END;

            lv_upd_message      :=
                replace_token_value (pv_msg         => lt_message,
                                     pv_token       => pv_token_name,
                                     pv_token_val   => pv_token_value);
            gv_exception_code   := pv_exception_code;
            gv_msg_string       := lv_upd_message;
            lv_token_updated    := 'Y';
        END IF;
    END set_exception_token;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : log_exception                                          --
    -- PARAMETERS  : pv_exception_code  - Exception code as in exception    --
    --                                    master                            --
    --           pv_component_name  - Component Name. If it is not       --
    --                    given for a concurrent program    --
    --                    it will be derived             --
    --           pv_application_code - Application Code. If it is not   --
    --                    given for a concurrent program    --
    --                    it will be derived             --
    --               pv_subprogram_code - package.procedure with in the     --
    --                                    program                           --
    --           pv_operation_code  - Operation Name in the program     --
    --           pv_operation_key   - Primary key to identify the record--
    --               pv_log_flag        - Flag to log the message in log    --
    --                                    file                              --
    --               pv_to_mailing_list - To mailing list              --
    --           pv_cc_mailing_list - CC mailing list              --
    --           pv_subject         - Subject                  --
    --           pv_body          - Body                  --
    --           pv_token_name1     - Token Name 1              --
    --           pv_token_value1    - Token Value 1              --
    --           pv_token_name2     - Token Name 2              --
    --           pv_token_value2    - Token Value 2              --
    --           pv_token_name3     - Token Name 3              --
    --           pv_token_value3    - Token Value 3              --
    --           pv_token_name4     - Token Name 4              --
    --           pv_token_value4    - Token Value 4              --
    --           pv_token_name5     - Token Name 5              --
    --           pv_token_value5    - Token Value 5              --
    --           pv_attribute1 - Additional Information in errors table --
    --           pv_attribute2 - Additional Information in errors table --
    --           pv_attribute3 - Additional Information in errors table --
    --           pv_attribute4 - Additional Information in errors table --
    --           pv_attribute5 - Additional Information in errors table --
    -- PURPOSE     : This procedure will be used to insert data into errors --
    --               table                                                  --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer             Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys             1.0          Initial Version         --
    -- 02/18/2013   Pushkal Mishra CG   1.1          Updated the logic for Notif Flag
    --------------------------------------------------------------------------
    PROCEDURE log_exception (pv_exception_code     IN VARCHAR2,
                             pv_component_name     IN VARCHAR2 DEFAULT NULL,
                             pv_application_code   IN VARCHAR2 DEFAULT NULL,
                             pv_subprogram_code    IN VARCHAR2 DEFAULT NULL,
                             pv_operation_code     IN VARCHAR2 DEFAULT NULL,
                             pv_operation_key      IN VARCHAR2 DEFAULT NULL,
                             pv_log_flag           IN VARCHAR2 DEFAULT 'Y',
                             pv_to_mailing_list    IN VARCHAR2 DEFAULT NULL,
                             pv_cc_mailing_list    IN VARCHAR2 DEFAULT NULL,
                             pv_subject            IN VARCHAR2 DEFAULT NULL,
                             pv_body               IN VARCHAR2 DEFAULT NULL,
                             pv_token_name1        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value1       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name2        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value2       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name3        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value3       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name4        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value4       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name5        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value5       IN VARCHAR2 DEFAULT NULL,
                             pv_attribute1         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute2         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute3         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute4         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute5         IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        -----------------------------
        -- Declare local variables --
        -----------------------------
        /*PM Added Cursor for Notif flag*/
        CURSOR csr_notif_type (lv_component_name VARCHAR2, lv_exception_code VARCHAR2, ln_application_id NUMBER)
        IS
            (SELECT xnd.notif_type
               FROM xxdo_notif_defns xnd
              WHERE     xnd.program_code =
                        NVL (gt_conc_program_name, lv_component_name)
                    AND xnd.exception_code = lv_exception_code
                    AND xnd.application_id =
                        NVL (gt_application_id, ln_application_id)
             UNION
             SELECT xnd.notif_type
               FROM xxdo_notif_defns xnd
              WHERE     xnd.program_code =
                        NVL (gt_conc_program_name, lv_component_name)
                    AND xnd.exception_code IS NULL
                    AND xnd.application_id =
                        NVL (gt_application_id, ln_application_id)
             UNION
             SELECT xnd.notif_type
               FROM xxdo_notif_defns xnd
              WHERE     xnd.program_code IS NULL
                    AND xnd.exception_code = lv_exception_code
                    AND xnd.application_id =
                        NVL (gt_application_id, ln_application_id)
             UNION
             SELECT xnd.notif_type
               FROM xxdo_notif_defns xnd
              WHERE     xnd.application_id =
                        NVL (gt_application_id, ln_application_id)
                    AND xnd.program_code IS NULL
                    AND xnd.exception_code IS NULL
             UNION
             SELECT xnd.notif_type
               FROM xxdo_notif_defns xnd
              WHERE     application_id IS NULL
                    AND xnd.program_code IS NULL
                    AND xnd.exception_code = lv_exception_code);

        CURSOR csr_notif_level (lv_component_name VARCHAR2, lv_exception_code VARCHAR2, ln_application_id NUMBER)
        IS
            SELECT notif_id, exception_flag, appl_expt_flag,
                   program_flag, application_flag, "LEVEL"
              FROM xxdo_notif_defns xnd
             WHERE     xnd.program_code =
                       NVL (gt_conc_program_name, lv_component_name)
                   AND xnd.exception_code = lv_exception_code
                   AND xnd.application_id =
                       NVL (gt_application_id, ln_application_id)
                   AND xnd.notif_type = 'B'
            UNION ALL
            SELECT notif_id, exception_flag, appl_expt_flag,
                   program_flag, application_flag, "LEVEL"
              FROM xxdo_notif_defns xnd
             WHERE     xnd.program_code =
                       NVL (gt_conc_program_name, lv_component_name)
                   AND xnd.exception_code IS NULL
                   AND xnd.application_id =
                       NVL (gt_application_id, ln_application_id)
                   AND xnd.notif_type = 'B'
            UNION ALL
            SELECT notif_id, exception_flag, appl_expt_flag,
                   program_flag, application_flag, "LEVEL"
              FROM xxdo_notif_defns xnd
             WHERE     xnd.program_code IS NULL
                   AND xnd.exception_code = lv_exception_code
                   AND xnd.application_id =
                       NVL (gt_application_id, ln_application_id)
                   AND xnd.notif_type = 'B'
            UNION ALL
            SELECT notif_id, exception_flag, appl_expt_flag,
                   program_flag, application_flag, "LEVEL"
              FROM xxdo_notif_defns xnd
             WHERE     xnd.application_id =
                       NVL (gt_application_id, ln_application_id)
                   AND xnd.program_code IS NULL
                   AND xnd.exception_code IS NULL
                   AND xnd.notif_type = 'B'
            UNION ALL
            SELECT notif_id, exception_flag, appl_expt_flag,
                   program_flag, application_flag, "LEVEL"
              FROM xxdo_notif_defns xnd
             WHERE     application_id IS NULL
                   AND xnd.program_code IS NULL
                   AND xnd.exception_code = lv_exception_code
                   AND xnd.notif_type = 'B'
            ORDER BY "LEVEL";

        ln_count            NUMBER := 0;
        lt_notif_flag       xxdo_errors.notif_flag%TYPE := NULL;
        lv_lvl_to_notify    VARCHAR2 (200);
        /*PM Updated the reference table from xxdo_notif_defns*/
        lt_application_id   fnd_concurrent_programs.application_id%TYPE
                                := NULL;
        lt_message          xxdo_errors.error_message%TYPE := NULL;
        lv_level2           VARCHAR2 (1) := 'Y';
        lv_level3           VARCHAR2 (1) := 'Y';
        lv_level4           VARCHAR2 (1) := 'Y';
        lv_level5           VARCHAR2 (1) := 'Y';
    BEGIN
        ---------------------------------------------
        -- Fetch user program from fnd tables name --
        ---------------------------------------------
        IF gt_conc_program_name IS NULL OR gt_application_id IS NULL
        THEN
            BEGIN
                SELECT fcp.concurrent_program_name, fcp.application_id
                  INTO gt_conc_program_name, gt_application_id
                  FROM fnd_concurrent_requests fcr, fnd_concurrent_programs fcp
                 WHERE     fcr.request_id = gn_conc_request_id
                       AND fcr.program_application_id = fcp.application_id
                       AND fcr.concurrent_program_id =
                           fcp.concurrent_program_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    gt_conc_program_name   := NULL;
                    gt_application_id      := NULL;
            END;
        END IF;

        ---------------------------------
        -- Deriving the application_id --
        ---------------------------------
        IF pv_application_code IS NOT NULL
        THEN
            BEGIN
                SELECT application_id
                  INTO lt_application_id
                  FROM fnd_application
                 WHERE application_short_name = pv_application_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lt_application_id   := NULL;
            END;
        END IF;



        ------------------------------------------------------------
        -- Fetch schedule run flag for exception and program code --
        ------------------------------------------------------------
        /*PM Updated the logic to fetch Notif type*/
        FOR lrec_notif_type
            IN csr_notif_type (pv_component_name,
                               pv_exception_code,
                               lt_application_id)
        LOOP
            lt_notif_flag   := lrec_notif_type.notif_type;
            ln_count        := ln_count + 1;
        END LOOP;

        IF ln_count = 0
        THEN
            lt_notif_flag   := 'NA';
        ELSIF ln_count > 1
        THEN
            lt_notif_flag   := 'IB';
        ELSE
            NULL;
        END IF;

        ------------------------------------
        -- updating levels to notify flag --
        ------------------------------------
        ln_count            := 0;

        IF lt_notif_flag = 'B' OR lt_notif_flag = 'IB'
        THEN
            FOR lrec_notif_level
                IN csr_notif_level (pv_component_name,
                                    pv_exception_code,
                                    lt_application_id)
            LOOP
                BEGIN
                    -- validate level 1
                    IF lrec_notif_level."LEVEL" = 1
                    THEN
                        lv_lvl_to_notify   := '-1';
                        -- set value for level 2 / 3 / 4 and 5
                        lv_level2          :=
                            NVL (lrec_notif_level.program_flag, 'N');
                        lv_level3          :=
                            NVL (lrec_notif_level.appl_expt_flag, 'N');
                        lv_level4          :=
                            NVL (lrec_notif_level.application_flag, 'N');
                        lv_level5          :=
                            NVL (lrec_notif_level.exception_flag, 'N');
                    END IF;

                    IF lrec_notif_level."LEVEL" = 2 AND lv_level2 = 'Y'
                    THEN
                        lv_lvl_to_notify   := lv_lvl_to_notify || '-2';

                        --- set value for 3 4 and 5
                        IF lv_level3 <> 'N'
                        THEN
                            lv_level3   :=
                                NVL (lrec_notif_level.appl_expt_flag, 'N');
                        END IF;

                        IF lv_level4 <> 'N'
                        THEN
                            lv_level4   :=
                                NVL (lrec_notif_level.application_flag, 'N');
                        END IF;

                        IF lv_level5 <> 'N'
                        THEN
                            lv_level5   :=
                                NVL (lrec_notif_level.exception_flag, 'N');
                        END IF;
                    END IF;

                    IF lrec_notif_level."LEVEL" = 3 AND lv_level3 = 'Y'
                    THEN
                        lv_lvl_to_notify   := lv_lvl_to_notify || '-3';

                        --- set value for 4 and 5
                        IF lv_level4 <> 'N'
                        THEN
                            lv_level4   :=
                                NVL (lrec_notif_level.application_flag, 'N');
                        END IF;

                        IF lv_level5 <> 'N'
                        THEN
                            lv_level5   :=
                                NVL (lrec_notif_level.exception_flag, 'N');
                        END IF;
                    END IF;

                    IF lrec_notif_level."LEVEL" = 4 AND lv_level4 = 'Y'
                    THEN
                        lv_lvl_to_notify   := lv_lvl_to_notify || '-4';

                        --- set value for 5
                        IF lv_level5 <> 'N'
                        THEN
                            lv_level5   :=
                                NVL (lrec_notif_level.exception_flag, 'N');
                        END IF;
                    END IF;

                    IF lrec_notif_level."LEVEL" = 5 AND lv_level5 = 'Y'
                    THEN
                        lv_lvl_to_notify   := lv_lvl_to_notify || '-5';
                    END IF;
                END;
            END LOOP;
        END IF;

        ---------------------------------
        -- Fetching the message string --
        ---------------------------------
        IF     pv_exception_code = gv_exception_code
           AND gv_msg_string IS NOT NULL
        THEN
            lt_message   := gv_msg_string;
        ELSE
            BEGIN
                SELECT MESSAGE
                  INTO lt_message
                  FROM xxdo_exception_defns
                 WHERE exception_code = pv_exception_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lt_message   := NULL;
            END;
        END IF;

        ----------------------------------
        -- Setting the exception tokens --
        ----------------------------------
        IF pv_token_name1 IS NOT NULL
        THEN
            gv_exception_code   := NULL;
            gv_msg_string       := NULL;
            lt_message          :=
                replace_token_value (lt_message,
                                     pv_token_name1,
                                     pv_token_value1);
        END IF;

        IF pv_token_name2 IS NOT NULL
        THEN
            gv_exception_code   := NULL;
            gv_msg_string       := NULL;
            lt_message          :=
                replace_token_value (lt_message,
                                     pv_token_name2,
                                     pv_token_value2);
        END IF;

        IF pv_token_name3 IS NOT NULL
        THEN
            gv_exception_code   := NULL;
            gv_msg_string       := NULL;
            lt_message          :=
                replace_token_value (lt_message,
                                     pv_token_name3,
                                     pv_token_value3);
        END IF;

        IF pv_token_name4 IS NOT NULL
        THEN
            gv_exception_code   := NULL;
            gv_msg_string       := NULL;
            lt_message          :=
                replace_token_value (lt_message,
                                     pv_token_name4,
                                     pv_token_value4);
        END IF;

        IF pv_token_name5 IS NOT NULL
        THEN
            gv_exception_code   := NULL;
            gv_msg_string       := NULL;
            lt_message          :=
                replace_token_value (lt_message,
                                     pv_token_name5,
                                     pv_token_value5);
        END IF;

        ------------------------------
        -- Insert into errors table --
        ------------------------------
        INSERT INTO xxdo_errors (error_id, exception_code, application_id,
                                 program_code, subprogram_code, operation_code, operation_key, request_id, error_message, notif_flag, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, created_by, creation_date, last_updated_by, last_update_date, last_update_login
                                 , levels_to_notify)
             VALUES (xxdo_error_id_seq.NEXTVAL, pv_exception_code, NVL (lt_application_id, gt_application_id), NVL (pv_component_name, gt_conc_program_name), pv_subprogram_code, pv_operation_code, pv_operation_key, NVL (gn_conc_request_id, -1), lt_message, lt_notif_flag, pv_attribute1, pv_attribute2, pv_attribute3, pv_attribute4, pv_attribute5, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, gn_user_id, gd_sysdate, gn_user_id, gd_sysdate, gn_login_id
                     , lv_lvl_to_notify);

        ----------------------------
        -- Commit the transaction --
        ----------------------------
        COMMIT;

        ----------------------------
        -- Reset Global variables --
        ----------------------------
        gv_exception_code   := NULL;
        gv_msg_string       := NULL;

        -------------------------------------
        --Log error in log file if required--
        -------------------------------------
        IF NVL (pv_log_flag, 'Y') = 'Y'
        THEN
            log_message (lt_message, 'LOG');
        END IF;
    END log_exception;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : log_message                                            --
    -- PARAMETERS  : pv_message      - Message to be logged                 --
    --               pv_destination  - Destination of message               --
    --                     Values can be - 'LOG','OUTPUT',      --
    --                     ,DBMS_OUTPUT','FILE','TABLE'      --
    --           pv_component_name - Component Name. If it is not       --
    --                       given for a concurrent program     --
    --                       it will be derived             --
    -- PURPOSE     : This procedure will be used to log messages for debug  --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE log_message (pv_message IN VARCHAR2, pv_destination IN VARCHAR2 DEFAULT NULL, pv_component_name IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        -----------------------------
        -- Declare local variables --
        -----------------------------
        lv_log_level        VARCHAR2 (240);
        trec_file_type      UTL_FILE.file_type;
        lv_trace_file       VARCHAR2 (240);
        lt_form_name        fnd_form.form_name%TYPE;
        lt_conc_prog_name   fnd_concurrent_programs.concurrent_program_name%TYPE;
        lv_destination      VARCHAR2 (240);
        lv_profile_dest     VARCHAR2 (240);
        lv_process_name     VARCHAR2 (240);
        lv_process_type     VARCHAR2 (20);
        ln_process_id       NUMBER;
    BEGIN
        --------------------------------------
        -- Get Profile value of debug level --
        --------------------------------------
        lv_log_level   := NVL (fnd_profile.VALUE ('XXCMN_DEBUG_LEVEL'), '0');

        IF lv_log_level <> '0' OR pv_destination IS NOT NULL
        THEN
            -----------------------------------------
            -- Get the destination for the message --
            ------------------------------------------
            IF pv_destination IS NOT NULL
            THEN
                lv_destination   := UPPER (pv_destination);
            END IF;

            IF lv_log_level <> '0'
            THEN
                SELECT DECODE (lv_log_level,  'D', 'DBMS_OUTPUT',  'F', 'FILE',  'L', 'LOG',  'O', 'OUTPUT',  'T', 'TABLE')
                  INTO lv_profile_dest
                  FROM DUAL;
            END IF;

            IF    lv_destination = 'DBMS_OUTPUT'
               OR lv_profile_dest = 'DBMS_OUTPUT'
            THEN
                DBMS_OUTPUT.put_line (pv_message);
            END IF;

            --------------------------------------------
            -- Checking if it is a concurrent request --
            --------------------------------------------
            IF gn_conc_request_id > 0
            THEN
                IF    lv_destination IN ('LOG', 'OUTPUT')
                   OR lv_profile_dest IN ('LOG', 'OUTPUT')
                THEN
                    -----------------------------------------------------
                    -- Check if message is coming from conc program    --
                    -- then log in log or output file otherwise ignore --
                    -----------------------------------------------------
                    IF lv_destination = 'LOG' OR lv_profile_dest = 'LOG'
                    THEN
                        fnd_file.put_line (fnd_file.LOG, pv_message);
                    END IF;

                    IF    lv_destination = 'OUTPUT'
                       OR lv_profile_dest = 'OUTPUT'
                    THEN
                        fnd_file.put_line (fnd_file.output, pv_message);
                    END IF;
                END IF;

                IF    lv_destination IN ('TABLE', 'FILE')
                   OR lv_profile_dest IN ('TABLE', 'FILE')
                THEN
                    ------------------------------------------
                    -- Deriving the concurrent program name --
                    ------------------------------------------
                    lt_conc_prog_name   := NULL;

                    BEGIN
                        SELECT fcp.concurrent_program_name, 'CONCURRENT PROGRAM', gn_conc_request_id
                          INTO lv_process_name, lv_process_type, ln_process_id
                          FROM fnd_concurrent_programs fcp
                         WHERE     fcp.concurrent_program_id =
                                   fnd_global.conc_program_id
                               AND fcp.application_id =
                                   fnd_global.prog_appl_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            raise_application_error (
                                -20001,
                                'No data found for the parameters of the program');
                        WHEN OTHERS
                        THEN
                            RAISE;
                    END;
                END IF;
            ------------------------------------------
            -- Checking if it is logged from a form --
            ------------------------------------------
            ELSIF     fnd_global.form_id > 0
                  AND (lv_destination IN ('TABLE', 'FILE') OR lv_profile_dest IN ('TABLE', 'FILE'))
            THEN
                BEGIN
                    SELECT ff.form_name, 'FORM', fnd_global.form_id
                      INTO lv_process_name, lv_process_type, ln_process_id
                      FROM fnd_form ff
                     WHERE     ff.form_id = fnd_global.form_id
                           AND ff.application_id = fnd_global.form_appl_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        raise_application_error (
                            -20001,
                            'No data found for the parameters for form');
                    WHEN OTHERS
                    THEN
                        RAISE;
                END;
            END IF;

            IF lv_destination = 'TABLE' OR lv_profile_dest = 'TABLE'
            THEN
                ------------------------------
                -- Log the message in table --
                ------------------------------
                BEGIN
                    INSERT INTO xxdo_log_messages (message_id, MESSAGE_TEXT, process_name, process_type, process_id, created_by, creation_date, last_updated_by, last_update_date
                                                   , last_update_login)
                         VALUES (xxdo_message_id_seq.NEXTVAL, pv_message, NVL (pv_component_name, lv_process_name), NVL (lv_process_type, 'OTHERS'), ln_process_id, gn_user_id, gd_sysdate, gn_user_id, gd_sysdate
                                 , gn_login_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        RAISE;
                END;
            END IF;

            IF lv_destination = 'FILE' OR lv_profile_dest = 'FILE'
            THEN
                lv_trace_file   :=
                       lv_process_name
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.out';
                trec_file_type   :=
                    UTL_FILE.fopen (gv_trace_dir, lv_trace_file, 'a',
                                    32760);
                UTL_FILE.put_line (trec_file_type, pv_message);
                ---------------------
                -- Close data file --
                ---------------------
                UTL_FILE.fclose (trec_file_type);
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ------------------------------
            -- Close any open data file --
            ------------------------------
            IF UTL_FILE.is_open (trec_file_type)
            THEN
                UTL_FILE.fclose (trec_file_type);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'log_message: Received error ' || SQLCODE || ' ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END log_message;
END xxdo_error_pkg;
/
