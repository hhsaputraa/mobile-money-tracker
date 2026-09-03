# Savings System & Dashboard Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the Dashboard screen into a full-featured Savings Tracker, allowing Admin to perform CRUD operations on deposit transactions for customers, and allowing customers (penabung) to view their own total balance and deposit transaction history.

**Architecture:** A PostgreSQL migration creates `savings_transactions` table with RLS and helper functions. In Dart, `SavingsTransactionModel` and `SavingsService` handle data abstraction and Supabase interaction. `DashboardScreen` adaptively presents a customer view (balance card with privacy toggle and personal transactions) or an admin view (overview metrics, customer filtering, and full transaction CRUD with dialogs).

**Tech Stack:** Flutter, Dart, Supabase Flutter SDK, PostgreSQL / PostgREST, `flutter_test`.

## Global Constraints

- Customers (`is_admin = false`) can ONLY view their own balance and transactions (read-only).
- Admin (`is_admin = true`) can input, edit, and delete deposit transactions for active customers.
- Transaction amount must always be greater than 0.
- Currency formatting must follow Indonesian standards (e.g. `Rp 1.500.000`).
- Code must pass `dart analyze` with 0 warnings and 0 errors.
- Code must pass all tests via `flutter test`.

---

### Task 1: Supabase Migration Script for Savings Transactions

**Files:**
- Create: `supabase/migrations/20260903_savings_transactions.sql`

**Interfaces:**
- Consumes: `public.profiles`
- Produces: `public.savings_transactions` table, RLS policies, RPC functions `get_my_savings_summary()` and `get_admin_savings_summary()`

- [ ] **Step 1: Write migration SQL file**
Create table with `id`, `user_id`, `amount`, `type`, `description`, `transaction_date`, `created_by`, `created_at`, `updated_at`. Add index, RLS policies, RPC functions, and permissions.

- [ ] **Step 2: Verify SQL syntax and completeness**
Inspect the file to ensure robust types, foreign keys, and security definer search paths.

---

### Task 2: Data Models & Unit Tests

**Files:**
- Create: `lib/savings/models/savings_transaction_model.dart`
- Create: `lib/savings/models/savings_summary_model.dart`
- Create: `test/savings/savings_model_test.dart`

**Interfaces:**
- Consumes: JSON maps from Supabase queries / RPC
- Produces: `SavingsTransactionModel` (with `formattedAmount` and `formattedDate`), `SavingsSummaryModel`

- [ ] **Step 1: Write unit tests for models in `test/savings/savings_model_test.dart`**
Test `fromJson`, `toJson`, `formattedAmount` with Rupiah formatting, and date formatting.

- [ ] **Step 2: Run test to verify it fails initially**
Run `flutter test test/savings/savings_model_test.dart`.

- [ ] **Step 3: Implement `SavingsTransactionModel` and `SavingsSummaryModel`**
Implement the classes under `lib/savings/models/`.

- [ ] **Step 4: Run test to verify it passes**
Run `flutter test test/savings/savings_model_test.dart`.

---

### Task 3: SavingsService Layer

**Files:**
- Create: `lib/savings/services/savings_service.dart`

**Interfaces:**
- Consumes: SupabaseClient, `UserModel`, `SavingsTransactionModel`
- Produces: `SavingsService` with methods: `getMyTotalBalance`, `getMyTransactions`, `getAdminOverview`, `getActiveCustomersList`, `getAllTransactions`, `createTransaction`, `updateTransaction`, `deleteTransaction`

- [ ] **Step 1: Implement `SavingsService`**
Write `lib/savings/services/savings_service.dart` with complete error handling, direct table queries, and PostgREST resilience.

---

### Task 4: Admin Transaction Dialog (Create & Edit)

**Files:**
- Create: `lib/savings/presentation/savings_transaction_dialog.dart`

**Interfaces:**
- Consumes: `SavingsService`, `UserModel`, `SavingsTransactionModel` (optional for edit mode)
- Produces: `SavingsTransactionDialog` widget for inputting/updating customer deposits

- [ ] **Step 1: Implement `SavingsTransactionDialog`**
Create the dialog with customer dropdown selector, amount input with auto-formatting, transaction date picker, description field, and validation.

---

### Task 5: Dashboard Screen Overhaul

**Files:**
- Modify: `lib/dashboard/presentation/dashboard_screen.dart`
- Modify: `test/dashboard/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `AuthService`, `SavingsService`, `SavingsTransactionModel`, `SavingsTransactionDialog`
- Produces: Overhauled `DashboardScreen` rendering Customer View or Admin View based on `isAdmin`

- [ ] **Step 1: Overhaul `DashboardScreen` widget structure**
Implement customer balance card (with balance visibility toggle and deposit history list) and admin dashboard (pool overview, quick actions, customer filter, search bar, and transaction CRUD list with edit/delete buttons).

- [ ] **Step 2: Update widget test in `test/dashboard/dashboard_screen_test.dart`**
Verify that `DashboardScreen` renders savings balance card for customer and admin management actions for admin.

- [ ] **Step 3: Run widget test to verify it passes**
Run `flutter test test/dashboard/dashboard_screen_test.dart`.

---

### Task 6: Static Analysis & Test Suite Verification

**Files:**
- All touched files

- [ ] **Step 1: Run `dart analyze`**
Ensure 0 errors and 0 warnings.

- [ ] **Step 2: Run `flutter test` across all tests**
Ensure all existing and new tests pass.
