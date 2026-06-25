-- =====================================================================
-- PostgreSQL equivalent of Oracle VENDEESYS.UPDATE_PASSWORD procedure
-- Converted from Oracle PL/SQL to Azure PostgreSQL (PL/pgSQL)
--
-- Conversion notes:
--   - VARCHAR2                      → VARCHAR
--   - NUMBER                        → NUMERIC
--   - SYSTIMESTAMP                  → CURRENT_TIMESTAMP
--   - SYSDATE                       → CURRENT_DATE
--   - OUT parameter                 → INOUT with DEFAULT NULL
--   - %ROWTYPE                      → same syntax works in PostgreSQL
--   - Local var named 'record'      → renamed to 'rec'
--                                     ('record' is a type keyword in PL/pgSQL)
--   - EXCEPTION WHEN NO_DATA_FOUND  → same in PL/pgSQL
--   - Password rotation SET clause  → PostgreSQL evaluates all right-hand
--                                     sides using old row values (same as Oracle),
--                                     so chained assignments are safe as-is
--
-- Result codes:
--   1 = パスワード更新成功 (Password updated successfully)
--   3 = ユーザーデータなし (No data found)
--   4 = パスワード認証失敗 (Current password mismatch)
--   5 = パスワードを間違えてロックされた (Wrong password → now locked)
--   6 = ユーザーはロックされている (User is locked)
--   7 = 過去パスワードと同一のため使用不可 (New password matches a previous password)
-- =====================================================================

CREATE OR REPLACE PROCEDURE vendeesys.update_password(
    IN    systemuserid  NUMERIC,
    IN    usercode      VARCHAR,
    IN    curpassword   VARCHAR,
    IN    newpassword   VARCHAR,
    IN    failurecount  NUMERIC,
    IN    checkgens     NUMERIC,
    INOUT result        NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Oracle: record PASSWORD_MANAGEMENT%ROWTYPE
    -- Renamed 'record' → 'rec' as 'record' is a type keyword in PL/pgSQL
    rec password_management%ROWTYPE;
BEGIN

    -- パスワード管理を検索して行ロック
    SELECT * INTO rec
      FROM password_management
     WHERE system_user_id = systemuserid
       AND available = 1
     FOR UPDATE;

    -- ロックパターン: ユーザはロックされている
    IF rec.attention_failure_count >= failurecount THEN
        result := 6;

    -- 認証失敗パターン
    ELSIF curpassword != rec.password THEN

        IF rec.attention_failure_count < (failurecount - 1) THEN
            -- ロックされていない状態でパスワードを間違えた
            result := 4;
        ELSIF rec.attention_failure_count = (failurecount - 1) THEN
            -- パスワードを間違えてロックされた
            result := 5;
        ELSIF rec.attention_failure_count >= failurecount THEN
            -- 暫定パスワードを間違えた
            result := 4;
        END IF;

        -- 認証失敗カウントを更新
        UPDATE password_management
           SET attention_failure_count = rec.attention_failure_count + 1,
               update_user             = usercode,
               update_date             = CURRENT_TIMESTAMP
         WHERE system_user_id = systemuserid;

    -- 認証成功パターン
    ELSIF curpassword = rec.password THEN

        -- 過去パスワードとの重複チェック
        IF newpassword = rec.password THEN
            result := 7;
        ELSIF checkgens > 0 AND newpassword = rec.password1 THEN
            result := 7;
        ELSIF checkgens > 1 AND newpassword = rec.password2 THEN
            result := 7;
        ELSIF checkgens > 2 AND newpassword = rec.password3 THEN
            result := 7;
        ELSIF checkgens > 3 AND newpassword = rec.password4 THEN
            result := 7;
        ELSIF checkgens > 4 AND newpassword = rec.password5 THEN
            result := 7;
        ELSE

            -- パスワードをローテーションして更新
            -- Note: PostgreSQL evaluates all right-hand sides from the original
            --       row values before applying any assignments (same as Oracle),
            --       so this chained rotation is safe.
            UPDATE password_management
               SET password                   = newpassword,
                   password1                  = password,    -- old password
                   password2                  = password1,   -- old password1
                   password3                  = password2,   -- old password2
                   password4                  = password3,   -- old password3
                   password5                  = password4,   -- old password4
                   attention_failure_count    = 0,
                   password_last_update_date  = CURRENT_DATE,
                   update_user                = usercode,
                   update_date                = CURRENT_TIMESTAMP
             WHERE system_user_id = systemuserid;

            result := 1;

        END IF;

    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- ユーザーデータなし
        result := 3;

END;
$$;


-- =====================================================================
-- Example: how to call the procedure
-- =====================================================================
-- DO $$
-- DECLARE
--     v_result NUMERIC;
-- BEGIN
--     CALL vendeesys.update_password(
--         systemuserid => 1,
--         usercode     => 'user001',
--         curpassword  => 'old_hashed_password',
--         newpassword  => 'new_hashed_password',
--         failurecount => 5,
--         checkgens    => 3,
--         result       => v_result
--     );
--     RAISE NOTICE 'Update password result: %', v_result;
--     -- 1=success, 3=not found, 4=wrong pw, 5=locked, 6=already locked, 7=reused pw
-- END;
-- $$;
