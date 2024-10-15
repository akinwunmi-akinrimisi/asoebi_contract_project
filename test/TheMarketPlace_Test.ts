import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';

describe('AsoEbiMarketPlace - User Registration', function () {
  // Fixture to deploy the contract
  async function deployMarketplaceFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, user1, user2] = await hre.ethers.getSigners();

    const AsoEbiMarketPlace = await hre.ethers.getContractFactory(
      'AsoEbiMarketPlace'
    );
    const marketplace = await AsoEbiMarketPlace.deploy(); // No need to call `.deployed()` here
    // await marketplace.deployed(); // Comment out or remove this line

    return { marketplace, owner, user1, user2 };
  }

  describe('User Registration', function () {
    it('Should allow a new user to register', async function () {
      const { marketplace, user1 } = await loadFixture(
        deployMarketplaceFixture
      );

      // User1 registers as a FabricSeller
      await expect(marketplace.connect(user1).registerUser('User One', 1)) // RoleType.FabricSeller = 1
        .to.emit(marketplace, 'UserRegistered') // Adjust event if necessary
        .withArgs(user1.address, 'User One', 1);

      // Verify that the user is registered
      const user = await marketplace.users(user1.address);
      expect(user.isRegistered).to.be.true;
      expect(user.displayName).to.equal('User One');
      expect(user.roleType).to.equal(1); // FabricSeller
    });

    it('Should prevent already registered users from registering again', async function () {
      const { marketplace, user1 } = await loadFixture(
        deployMarketplaceFixture
      );

      // User1 registers initially
      await marketplace.connect(user1).registerUser('User One', 1); // RoleType.FabricSeller = 1

      // Attempt to register the same user again
      await expect(marketplace.connect(user1).registerUser('User One Again', 2)) // RoleType.Designer = 2
        .to.be.revertedWithCustomError(marketplace, 'NotANewUser')
        .withArgs(user1.address); // Expect the correct revert message and arguments
    });
  });
});
