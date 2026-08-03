import { Editor } from "@tldraw/tldraw";
const e = {} as Editor;
e.store.listen((update) => {
  console.log(update.changes);
});
e.store.mergeRemoteChanges(() => {
  e.store.applyDiff(null as any);
});
