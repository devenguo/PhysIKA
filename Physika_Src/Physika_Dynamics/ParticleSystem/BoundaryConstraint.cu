#include "BoundaryConstraint.h"
#include "Physika_Core/Utilities/cuda_utilities.h"
#include "Physika_Framework/Framework/Log.h"
#include "Physika_Framework/Framework/Node.h"
#include "Physika_Core/Utilities/CudaRand.h"

#include "Physika_Geometry/SDF/DistanceField3D.h"

namespace Physika
{
	IMPLEMENT_CLASS_1(BoundaryConstraint, TDataType)

	template<typename TDataType>
	BoundaryConstraint<TDataType>::BoundaryConstraint()
		: ConstraintModule()
	{
		Coord lo(0.0f);
		Coord hi(1.0f);
		m_cSDF = std::make_shared<DistanceField3D<DataType3f>>();
		m_cSDF->SetSpace(lo - 0.025f, hi + 0.025f, 105, 105, 105);
		m_cSDF->DistanceFieldToBox(lo, hi, true);
	}

	template<typename TDataType>
	BoundaryConstraint<TDataType>::~BoundaryConstraint()
	{
		m_cSDF->Release();
	}

	template<typename Real, typename Coord, typename TDataType>
	__global__ void K_ConstrainSDF(
		DeviceArray<Coord> posArr,
		DeviceArray<Coord> velArr,
		DistanceField3D<TDataType> df,
		Real normalFriction,
		Real tangentialFriction,
		Real dt)
	{
		int pId = threadIdx.x + (blockIdx.x * blockDim.x);
		if (pId >= posArr.size()) return;

		Coord pos = posArr[pId];
		Coord vec = velArr[pId];

		Real dist;
		Coord normal;
		df.GetDistance(pos, dist, normal);
		// constrain particle
		if (dist <= 0) {
			Real olddist = -dist;
			RandNumber rGen(pId);
			dist = 0.0001f*rGen.Generate();
			// reflect position
			pos -= (olddist + dist)*normal;
			// reflect velocity
			Real vlength = vec.norm();
			Real vec_n = vec.dot(normal);
			Coord vec_normal = vec_n*normal;
			Coord vec_tan = vec - vec_normal;
			if (vec_n > 0) vec_normal = -vec_normal;
			vec_normal *= (1.0f - normalFriction);
			vec = vec_normal + vec_tan;
			vec *= pow(Real(M_E), -dt*tangentialFriction);
		}

		posArr[pId] = pos;
		velArr[pId] = vec;
	}

	template<typename TDataType>
	bool BoundaryConstraint<TDataType>::constrain()
	{
		cuint pDim = cudaGridSize(m_position.getElementCount(), BLOCK_SIZE);
		K_ConstrainSDF << <pDim, BLOCK_SIZE >> > (
			m_position.getValue(),
			m_velocity.getValue(),
			*m_cSDF,
			m_normal_friction,
			m_tangent_friction,
			getParent()->getDt());

		return true;
	}

	template<typename TDataType>
	bool BoundaryConstraint<TDataType>::constrain(DeviceArray<Coord>& position, DeviceArray<Coord>& velocity, Real dt)
	{
		cuint pDim = cudaGridSize(position.size(), BLOCK_SIZE);
		K_ConstrainSDF << <pDim, BLOCK_SIZE >> > (
			position,
			velocity,
			*m_cSDF,
			m_normal_friction,
			m_tangent_friction,
			dt);

		return true;
	}

}