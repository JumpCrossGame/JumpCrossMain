import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const JCV2Module = buildModule("JumpCrossV2", (m) => {
  const jccAddress = "0xD59BE5afE8cF939BfFBC1Cb3D2c5545eBD8A7917";
  const jcv2Module = m.contract("JumpCrossV2", [jccAddress]);

  return { jcv2Module };
});

export default JCV2Module;
