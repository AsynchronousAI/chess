import React, {
  useEffect,
  useState,
  forwardRef,
  useImperativeHandle,
} from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Frame, Text } from "@rbxts/better-react-components";
import { AnalyzeMates } from "shared/engine/legalMoves";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "../usePx";

export interface EvaluationBarRef {
  setEval: (value: number) => void;
  setMate: (value: number) => void;
}

export const EvaluationBar = forwardRef<EvaluationBarRef>((props, ref) => {
  const board = useAtom(Atoms.Board);
  const px = usePx();

  const [evaluation, setEval] = useState(0);
  const [mate, setMate] = useState(0);
  const [evalBar, evalBarMotion] = useMotion(0.5);
  const [evalText, setEvalText] = useState("");

  useImperativeHandle(ref, () => ({
    setEval,
    setMate,
  }));

  useEffect(() => {
    const analysis = AnalyzeMates(board);
    if (analysis === "stalemate" || analysis === "insufficent") {
      evalBarMotion.spring(0.5);
      setEval(-1);
      setEvalText("1/2");
    } else if (analysis === "checkmate") {
      /* checkmate */
      evalBarMotion.spring(mate > 0 ? 0 : 1);
      setEval(mate > 0 ? 1 : -1);
      setEvalText(mate > 0 ? "1-0" : "0-1");
    } else if (mate > 0) {
      /* black mate */
      evalBarMotion.spring(0);
      setEval(1);
      setEvalText(`M${mate}`);
    } else if (mate < 0) {
      /* white mate */
      evalBarMotion.spring(1);
      setEval(-1);
      setEvalText(`M${math.abs(mate - 1)}`);
    } else {
      /* midgame */
      const scale = 500;
      const probability = 1 / (1 + math.pow(10, evaluation / scale));
      const mapped = math.min(math.max(probability, 0), 1);

      evalBarMotion.spring(mapped);
      setEvalText(
        string.format(
          "%.1f",
          (evaluation > 0 ? evaluation : 1 - evaluation) / 100,
        ),
      );
    }
  }, [evaluation, mate, board]);

  return (
    <Frame size={new UDim2(0.025, 0, 1, 0)} background={"#403E39"}>
      <Frame
        size={evalBar.map((value) => new UDim2(1, 0, value, 0))}
        position={evalBar.map((value) => new UDim2(0, 0, 1 - value, 0))}
        background={new Color3(1, 1, 1)}
      />
      <Text
        size={new UDim2(1, 0, 0, px(20))}
        text={evalText}
        noBackground
        textColor={
          evaluation <= 0 ? new Color3(0.45, 0.45, 0.45) : new Color3(1, 1, 1)
        }
        font={"SourceSansBold"}
        textSize={px(14)}
        position={
          evaluation <= 0
            ? new UDim2(0, 0, 1, -px(25))
            : new UDim2(0, 0, 0, px(2))
        }
      />
    </Frame>
  );
});
