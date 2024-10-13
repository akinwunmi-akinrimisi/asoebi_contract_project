import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { AsoEbiMarketPlace, MockEscrow } from "../typechain-types";
// import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("AsoEbiMarketPlace", function () {
    async function deployContractFixture() {
        const [owner, addr1, addr2] = await ethers.getSigners();

        const EscrowMock = await ethers.getContractFactory("MockEscrow");
        const escrowMock = await EscrowMock.deploy();


        const AsoEbiMarketPlace = await ethers.getContractFactory("AsoEbiMarketPlace");
        const asoEbiMarketPlace = await AsoEbiMarketPlace.deploy(escrowMock.target);


        return { asoEbiMarketPlace, escrowMock, owner, addr1, addr2 };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { asoEbiMarketPlace, owner } = await loadFixture(deployContractFixture);
            expect(await asoEbiMarketPlace.owner()).to.equal(owner.address);
        });

        it("Should set the correct escrow address", async function () {
            const { asoEbiMarketPlace, escrowMock } = await loadFixture(deployContractFixture);
            expect(await asoEbiMarketPlace.escrowAddress()).to.equal(escrowMock.target);
        });
    });


    describe("User Registration", function () {
        it("Should register a new user", async function () {
            const { asoEbiMarketPlace, addr1 } = await loadFixture(deployContractFixture);

            await asoEbiMarketPlace.connect(addr1).registerUser("TestUser", 1); // 1 for FabricSeller

            const user = await asoEbiMarketPlace.users(addr1.address);
            expect(user.displayName).to.equal("TestUser");
            expect(user.roleType).to.equal(1);
            expect(user.isRegistered).to.be.true;
        });

        it("Should revert when registering an already registered user", async function () {
            const { asoEbiMarketPlace, addr1 } = await loadFixture(deployContractFixture);

            await asoEbiMarketPlace.connect(addr1).registerUser("TestUser", 1);

            await expect(asoEbiMarketPlace.connect(addr1).registerUser("NewName", 2))
                .to.be.revertedWithCustomError(asoEbiMarketPlace, "NotANewUser")
                .withArgs(addr1.address);
        });
    });





});