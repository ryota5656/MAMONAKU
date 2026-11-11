import * as logger from "firebase-functions/logger";
import { PROJECT_ID, TASKS_LOCATION, TASKS_QUEUE, TASK_SECRET } from "./config.js";
import { errorMessage, tasksClient } from "./firebase.js";
import { liveActivityDeviceDoc } from "./store.js";
import { RotationPayload } from "./types.js";

/** gRPC のステータスコード */
const GRPC_NOT_FOUND = 5;
const GRPC_ALREADY_EXISTS = 6;

/** Cloud Tasks から `executeLiveActivityRotation` へ送るリクエスト本文 */
export interface ExecuteRotationRequestBody {
  deviceId: string;
  rotationIndex: number;
}

const queuePath = () => tasksClient.queuePath(PROJECT_ID, TASKS_LOCATION, TASKS_QUEUE);
const executeFunctionUrl = () =>
  `https://${TASKS_LOCATION}-${PROJECT_ID}.cloudfunctions.net/executeLiveActivityRotation`;

/** 切り替えごとに、その時刻に `executeLiveActivityRotation` を呼ぶタスクを登録する。登録したタスク名を返す。 */
export async function scheduleRotationTasks(deviceId: string, rotations: RotationPayload[]): Promise<string[]> {
  await ensureQueue();
  const parent = queuePath();
  const url = executeFunctionUrl();
  const taskNames: string[] = [];

  for (const [rotationIndex, rotation] of rotations.entries()) {
    const body: ExecuteRotationRequestBody = { deviceId, rotationIndex };
    const [task] = await tasksClient.createTask({
      parent,
      task: {
        scheduleTime: { seconds: rotation.switchAtUnix },
        httpRequest: {
          httpMethod: "POST",
          url,
          headers: {
            "Content-Type": "application/json",
            "X-Task-Secret": TASK_SECRET,
          },
          body: Buffer.from(JSON.stringify(body)).toString("base64"),
        },
      },
    });
    if (task.name) taskNames.push(task.name);
  }
  return taskNames;
}

/** 端末に登録済みの切り替えタスクを取り消す。取り消しの失敗はログだけ残して続ける。 */
export async function cancelScheduledTasks(deviceId: string): Promise<void> {
  const doc = await liveActivityDeviceDoc(deviceId).get();
  const taskNames: string[] = doc.data()?.scheduledTaskNames ?? [];
  await Promise.all(
    taskNames.map(async (name) => {
      try {
        await tasksClient.deleteTask({ name });
      } catch (error) {
        logger.warn("Failed to delete task", { name, error: errorMessage(error) });
      }
    })
  );
}

/** キューが無ければ作る。 */
async function ensureQueue(): Promise<void> {
  const name = queuePath();
  try {
    await tasksClient.getQueue({ name });
    return;
  } catch (error) {
    if (grpcCode(error) !== GRPC_NOT_FOUND) throw error;
  }

  try {
    await tasksClient.createQueue({
      parent: tasksClient.locationPath(PROJECT_ID, TASKS_LOCATION),
      queue: { name },
    });
  } catch (error) {
    if (grpcCode(error) === GRPC_ALREADY_EXISTS) return;
    throw error;
  }
}

function grpcCode(error: unknown): number | undefined {
  return (error as { code?: number }).code;
}
