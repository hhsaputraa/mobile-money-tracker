# Admin Soft Delete User Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an Admin Soft Delete feature for users in Money Tracker, ensuring deleted users disappear from the mobile UI, remain inactive in Supabase backend, and cannot log in (showing a generic invalid credentials message).

**Architecture:** A PostgreSQL migration adds `is_active` to `public.profiles` and creates an `admin_soft_delete_user` RPC. The Dart client layers (`UserModel`, `UserManagementService`, `AuthService`) query only active users and block login for deactivated accounts. The Flutter UI in `UserManagementScreen` provides a delete action with confirmation dialog, hiding the button for the currently authenticated admin.

**Tech Stack:** Flutter, Dart, Supabase Flutter SDK, PostgreSQL / PostgREST RPC, `flutter_test`.

## Global Constraints

- Never allow an Admin to delete their own account.
- When an inactive (`is_active = false`) user tries to log in, return the exact message: `"Username/Email atau password salah. Silakan periksa kembali."`
- Inactive users must never appear in `UserManagementScreen`.
- Code must pass `dart analyze` with 0 warnings and 0 errors.
- Code must pass `flutter test`.

---

### Task 1: Supabase Migration Script for Soft Delete

**Files:**
- Create: `supabase/migrations/20260903_admin_soft_delete_user.sql`

**Interfaces:**
- Consumes: `public.profiles`, `auth.users`
- Produces: RPC `public.admin_soft_delete_user(target_user_id UUID)` returning JSONB, and `is_active` column on `public.profiles`

- [ ] **Step 1: Write SQL migration file**
Add the migration script with table alteration, safe column addition, RPC function, security grants, and schema reload.

- [ ] **Step 2: Verify SQL syntax and completeness**
Inspect the file to ensure proper error handling when target user doesn't exist or is self (`auth.uid()`).

---

### Task 2: UserModel `isActive` Property & Unit Tests

**Files:**
- Modify: `lib/auth/models/user_model.dart`
- Create / Modify: `test/auth/user_model_test.dart`

**Interfaces:**
- Consumes: JSON map from Supabase profiles / auth
- Produces: `UserModel.isActive` boolean (defaults to `true` when null)

- [ ] **Step 1: Write unit test for `UserModel` parsing `isActive`**
Create `test/auth/user_model_test.dart` testing `isActive` defaults to `true` when absent or null, and parses `false` when explicit.

- [ ] **Step 2: Run test to verify it fails if not implemented**
Run `flutter test test/auth/user_model_test.dart`.

- [ ] **Step 3: Update `UserModel` implementation**
Update `lib/auth/models/user_model.dart` to handle `json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'] == 1)`.

- [ ] **Step 4: Run test to verify it passes**
Run `flutter test test/auth/user_model_test.dart`.

---

### Task 3: UserManagementService & AuthService Updates

**Files:**
- Modify: `lib/user_management/services/user_management_service.dart`
- Modify: `lib/auth/services/auth_service.dart`
- Create / Modify: `test/user_management/user_management_service_test.dart`

**Interfaces:**
- Consumes: Supabase client, `UserModel`
- Produces: `UserManagementService.adminDeleteUser(String userId)`, `UserManagementService.fetchUsersList()` filtering `is_active=true`, `AuthService.login()` rejecting `isActive == false`

- [ ] **Step 1: Update `fetchUsersList` to filter active users**
Filter `client.from('profiles').select().eq('is_active', true).order('created_at', ascending: false)`.

- [ ] **Step 2: Add `adminDeleteUser` in `UserManagementService`**
Implement calling `admin_soft_delete_user` RPC, with fallback to updating `is_active: false` in `profiles` directly if RPC cache is not updated yet.

- [ ] **Step 3: Update `AuthService._enrichUserModelWithProfile` & `login`**
Include `is_active` in select query. If `userModel.isActive == false`, sign out and return `AuthResult.failure('Username/Email atau password salah. Silakan periksa kembali.')`.

- [ ] **Step 4: Run unit tests to verify services**
Run `flutter test`.

---

### Task 4: UserManagementScreen UI & Confirmation Dialog

**Files:**
- Modify: `lib/user_management/presentation/user_management_screen.dart`

**Interfaces:**
- Consumes: `AuthService().currentUser.value?.id`, `UserManagementService().adminDeleteUser`
- Produces: Delete icon button on `_UserCardTile`, `_confirmDeleteUser(UserModel user)` dialog

- [ ] **Step 1: Pass current admin ID to `_UserCardTile`**
Ensure that `_UserCardTile` knows whether the user is the currently logged-in Admin, hiding the delete button if `user.id == currentUserId`.

- [ ] **Step 2: Implement delete confirmation dialog in `UserManagementScreen`**
Create `_confirmDeleteUser(UserModel user)` showing a red warning confirmation dialog with loading indicator during deletion.

- [ ] **Step 3: On successful deletion, update local state and notify user**
Remove the user from `_allUsers` and `_filteredUsers`, call `setState`, and show a SnackBar.

---

### Task 5: Validation, Static Analysis & Testing

**Files:**
- All touched files

- [ ] **Step 1: Run `dart analyze`**
Ensure 0 errors and 0 warnings.

- [ ] **Step 2: Run `flutter test`**
Ensure all tests pass.
