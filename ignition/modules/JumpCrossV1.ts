import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const JCV1Module = buildModule("JumpCrossV1", (m) => {
  const jccAddress = "0xD59BE5afE8cF939BfFBC1Cb3D2c5545eBD8A7917";
  const jcv1Module = m.contract("JumpCrossV1", [jccAddress]);

  return { jcv1Module };
});

export default JCV1Module;
