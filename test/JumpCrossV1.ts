import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("JumpCrossV1", function () {
  async function deploy() {
    const provider = hre.ethers.provider;
    const [owner, acc1, acc2, acc3, acc4] = await hre.ethers.getSigners();

    const JCC = await hre.ethers.getContractFactory("JumpCrossCoupon");
    const jcc = await JCC.deploy();

    const JCV1 = await hre.ethers.getContractFactory("JumpCrossV1");
    const jcv1 = await JCV1.deploy(jcc);

    return { provider, jcv1, jcc, owner, acc1, acc2, acc3, acc4 };
  }

  describe("Deployment", function () {
    it("State: Should set the right owner", async function () {
      const { jcv1, owner } = await loadFixture(deploy);

      expect(await jcv1.owner()).to.equal(owner.address);
    });

    it("State: Should set the right ERC20 contract", async function () {
      const { jcv1, jcc } = await loadFixture(deploy);

      expect(await jcv1.jcc()).to.equal(jcc);
    });
  });

  describe("Game functions", function () {
    it("Build map successfully", async function () {
      const { jcv1, owner, jcc } = await loadFixture(deploy);

      await jcc.pawn(BigInt(10000), { value: ethers.parseEther("0.14112") });
      await jcc.approve(jcv1, BigInt(10000));

      await expect(jcv1.buildMap("mockPaymentId", "sliver", BigInt(900), BigInt(300)))
        .to.emit(jcv1, "Build")
        .withArgs(owner.address, "sliver", "mockPaymentId", BigInt(900), BigInt(300));
    });

    it("Create space successfully", async function () {
      const { jcv1, owner, jcc } = await loadFixture(deploy);

      await jcc.pawn(BigInt(10000), { value: ethers.parseEther("0.14112") });
      await jcc.approve(jcv1, BigInt(10000));

      await expect(jcv1.createSpace("mockPaymentId", "mockMapId", BigInt(0), BigInt(240), BigInt(40)))
        .to.emit(jcv1, "Create")
        .withArgs(owner.address, "mockMapId", "mockPaymentId", BigInt(0), BigInt(240), BigInt(40));
    });

    it("Ready at a space successfully", async function () {
      const { jcv1, owner, jcc } = await loadFixture(deploy);

      await jcc.pawn(BigInt(10000), { value: ethers.parseEther("0.14112") });
      await jcc.approve(jcv1, BigInt(10000));

      await expect(jcv1.readyAt("mockPaymentId", "mockMapId", BigInt(240), BigInt(40)))
        .to.emit(jcv1, "Ready")
        .withArgs(owner.address, "mockMapId", "mockPaymentId", BigInt(240), BigInt(40));
    });

    it("Upload a game result successfully", async function () {
      const { jcv1, owner } = await loadFixture(deploy);

      await expect(jcv1.upload(owner.address, "mockMapId", BigInt(177)))
        .to.emit(jcv1, "Upload")
        .withArgs(owner.address, "mockMapId", BigInt(177));
    });

    it("Settle a map successfully: (Ex: Silver, 12 joiner)", async function () {
      const { jcv1, owner, acc1, acc2, acc3 } = await loadFixture(deploy);

      const totalReward = BigInt(3000);
      const BuilderReward = (totalReward * BigInt(28)) / BigInt(100);
      const ProtocolRevenue = (totalReward * BigInt(4)) / BigInt(100);
      const winnerPool = totalReward - (BuilderReward + ProtocolRevenue);
      const reward0 = (winnerPool * BigInt(5)) / BigInt(10);
      const reward1 = (winnerPool * BigInt(3)) / BigInt(10);
      const reward2 = winnerPool - (reward0 + reward1);

      const winners = [acc1.address, acc2.address, acc3.address];

      const rewards = [reward0, reward1, reward2];

      await expect(jcv1.settle("mockMapId", owner.address, BuilderReward, ProtocolRevenue, winners, rewards))
        .to.emit(jcv1, "Settle")
        .withArgs("mockMapId", owner.address, BuilderReward)
        .and.to.emit(jcv1, "Share")
        .withArgs("mockMapId", ProtocolRevenue)
        .and.to.emit(jcv1, "Distribute")
        .withArgs("mockMapId", winners[0], rewards[0])
        .and.to.emit(jcv1, "Distribute")
        .withArgs("mockMapId", winners[1], rewards[1])
        .and.to.emit(jcv1, "Distribute")
        .withArgs("mockMapId", winners[2], rewards[2]);
    });
  });

  describe("Claim", function () {
    it("interation test: (Ex: Gold, 4 joiner)", async function () {
      const { jcv1, jcc, owner, acc1, acc2, acc3, acc4 } = await loadFixture(deploy);

      async function mintJCC(account: HardhatEthersSigner, amount: number, etherValue: string) {
        await jcc.connect(account).pawn(BigInt(amount), { value: ethers.parseEther(etherValue) });
        await jcc.connect(account).approve(jcv1, BigInt(amount));
      }

      // Simulate play once in gold map
      async function playOnce(accounts: HardhatEthersSigner[]) {
        // more than or equal to 1
        expect(accounts.length).to.be.gte(1);

        await expect(
          jcv1.connect(accounts[0]).createSpace("mockPaymentId", "mockMapId", BigInt(0), BigInt(360), BigInt(60))
        )
          .to.emit(jcv1, "Create")
          .withArgs(accounts[0].address, "mockMapId", "mockPaymentId", BigInt(0), BigInt(360), BigInt(60));

        for (let i = 1; i < accounts.length; i++) {
          await expect(jcv1.connect(accounts[i]).readyAt("mockPaymentId", "mockMapId", BigInt(360), BigInt(60)))
            .to.emit(jcv1, "Ready")
            .withArgs(accounts[i].address, "mockMapId", "mockPaymentId", BigInt(360), BigInt(60));
        }
      }

      // Simulate settle a gold map with total 4 joiner
      async function settle(accounts: HardhatEthersSigner[]) {
        expect(accounts.length).to.be.gte(1);

        const totalReward = BigInt(2100);
        const BuilderReward = (totalReward * BigInt(29)) / BigInt(100);
        const ProtocolReward = (totalReward * BigInt(2)) / BigInt(100);
        const winnerPool = totalReward - (BuilderReward + ProtocolReward);
        const reward0 = (winnerPool * BigInt(5)) / BigInt(10);
        const reward1 = (winnerPool * BigInt(3)) / BigInt(10);
        const reward2 = winnerPool - (reward0 + reward1);

        const winners = [acc1.address, acc2.address, acc3.address];
        const rewards = [reward0, reward1, reward2];

        await expect(jcv1.settle("mockMapId", owner.address, BuilderReward, ProtocolReward, winners, rewards))
          .to.emit(jcv1, "Settle")
          .withArgs("mockMapId", owner.address, BuilderReward)
          .and.to.emit(jcv1, "Share")
          .withArgs("mockMapId", ProtocolReward)
          .and.to.emit(jcv1, "Distribute")
          .withArgs("mockMapId", accounts[0].address, reward0)
          .and.to.emit(jcv1, "Distribute")
          .withArgs("mockMapId", accounts[1].address, reward1)
          .and.to.emit(jcv1, "Distribute")
          .withArgs("mockMapId", accounts[2].address, reward2);
      }

      // before test
      await mintJCC(owner, 10000, "0.14112");
      await mintJCC(acc1, 10000, "0.14112");
      await mintJCC(acc2, 10000, "0.14112");
      await mintJCC(acc3, 10000, "0.14112");
      await mintJCC(acc4, 10000, "0.14112");

      // build
      await expect(jcv1.connect(owner).buildMap("mockPaymentId", "gold", BigInt(1300), BigInt(400)))
        .to.emit(jcv1, "Build")
        .withArgs(owner.address, "gold", "mockPaymentId", BigInt(1300), BigInt(400));

      // create & ready
      await playOnce([acc1, acc2, acc3, acc4]);

      // upload
      await expect(jcv1.upload(acc1.address, "mockMapId", BigInt(145)))
        .to.emit(jcv1, "Upload")
        .withArgs(acc1.address, "mockMapId", BigInt(145));

      await expect(jcv1.upload(acc2.address, "mockMapId", BigInt(167)))
        .to.emit(jcv1, "Upload")
        .withArgs(acc2.address, "mockMapId", BigInt(167));

      await expect(jcv1.upload(acc3.address, "mockMapId", BigInt(178)))
        .to.emit(jcv1, "Upload")
        .withArgs(acc3.address, "mockMapId", BigInt(178));

      await expect(jcv1.upload(acc4.address, "mockMapId", ethers.MaxUint256))
        .to.emit(jcv1, "Upload")
        .withArgs(acc4.address, "mockMapId", ethers.MaxUint256);

      // settle
      await settle([acc1, acc2, acc3]);

      // claim
      // check rewards of owner

      // owner will get "builder reward:609" + "protocol reward:640" + "shared revenue:42" = "1291"
      await expect(jcv1.connect(owner).claim()).to.emit(jcc, "Transfer").withArgs(jcv1, owner.address, BigInt(1291));

      // simulated top 1 will get 50% from reward pool
      await expect(jcv1.connect(acc1).claim()).to.emit(jcc, "Transfer").withArgs(jcv1, acc1.address, BigInt(724));

      // simulated top 2 will get 30% from reward pool
      await expect(jcv1.connect(acc2).claim()).to.emit(jcc, "Transfer").withArgs(jcv1, acc2.address, BigInt(434));

      // simulated top 3 will get 20% from reward pool
      await expect(jcv1.connect(acc3).claim()).to.emit(jcc, "Transfer").withArgs(jcv1, acc3.address, BigInt(291));

      expect(await jcc.balanceOf(jcv1)).to.equal(BigInt(0));
    });
  });
});
