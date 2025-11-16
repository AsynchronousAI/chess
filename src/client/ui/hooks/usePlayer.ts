import { useEffect, useState } from "@rbxts/react";
import { Players } from "@rbxts/services";

export function usePlayer(userId: number) {
  const [name, setName] = useState("Loading..");
  const [thumbnail, setThumbnail] = useState("");

  useEffect(() => {
    if (userId > 0) {
      setName(Players.GetNameFromUserIdAsync(userId));
      const [content, _success] = Players.GetUserThumbnailAsync(
        userId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size420x420,
      );
      setThumbnail(content);
    } else if (userId < 0) {
      setName("Bot");
    }
  }, [userId]);

  return [name, thumbnail];
}
