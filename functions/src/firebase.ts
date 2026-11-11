import * as admin from "firebase-admin";
import { CloudTasksClient } from "@google-cloud/tasks";
import { setGlobalOptions } from "firebase-functions";

// 関数の定義より先に評価される必要があるため、各関数が import するこのモジュールで設定する。
setGlobalOptions({ maxInstances: 10 });
admin.initializeApp();

export const db = admin.firestore();
export const messaging = admin.messaging();
export const auth = admin.auth();
export const tasksClient = new CloudTasksClient();

export const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

export function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}
