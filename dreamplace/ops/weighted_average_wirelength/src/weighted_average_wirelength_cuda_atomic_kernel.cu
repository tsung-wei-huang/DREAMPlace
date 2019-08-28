#include <cfloat>
#include <stdio.h>
#include "assert.h"
#include "cuda_runtime.h"
#include "utility/src/print.h"
#include "utility/src/Msg.h"
#include "weighted_average_wirelength/src/functional_cuda.h"

DREAMPLACE_BEGIN_NAMESPACE

template <typename T, typename V>
int computeWeightedAverageWirelengthCudaAtomicLauncher(
        const T* x, const T* y, 
        const int* pin2net_map, 
        const unsigned char* net_mask, 
        int num_nets,
        int num_pins, 
        const T* gamma, 
        T* exp_xy, T* exp_nxy, 
        T* exp_xy_sum, T* exp_nxy_sum, 
        T* xyexp_xy_sum, T* xyexp_nxy_sum, 
        V* xy_max, V* xy_min, 
        T* partial_wl, // wirelength of each net 
        const T* grad_tensor, 
        T* grad_x_tensor, T* grad_y_tensor // the gradient is partial total wirelength to partial pin position  
        )
{
    int thread_count = 1024; 
    int block_count_pins = (num_pins - 1 + thread_count) / thread_count;

    cudaError_t status; 
    cudaStream_t stream_x_exp; 
    cudaStream_t stream_nx_exp; 
    cudaStream_t stream_y_exp; 
    cudaStream_t stream_ny_exp; 
    status = cudaStreamCreate(&stream_x_exp);
    if (status != cudaSuccess)
    {
        printf("cudaStreamCreate failed for stream_x_exp\n");
        fflush(stdout);
        return 1; 
    }
    status = cudaStreamCreate(&stream_y_exp);
    if (status != cudaSuccess)
    {
        printf("cudaStreamCreate failed for stream_y_exp\n");
        fflush(stdout);
        return 1; 
    }

    if (grad_tensor)
    {
        computeWeightedAverageWirelengthGrad<<<block_count_pins, thread_count, 0, stream_x_exp>>>(
                x, 
                exp_xy, exp_nxy, 
                exp_xy_sum, exp_nxy_sum, 
                xyexp_xy_sum, xyexp_nxy_sum, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                grad_tensor, 
                grad_x_tensor
                );
        computeWeightedAverageWirelengthGrad<<<block_count_pins, thread_count, 0, stream_y_exp>>>(
                y, 
                exp_xy+num_pins, exp_nxy+num_pins, 
                exp_xy_sum+num_nets, exp_nxy_sum+num_nets, 
                xyexp_xy_sum+num_nets, xyexp_nxy_sum+num_nets, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                grad_tensor, 
                grad_y_tensor
                );
    }
    else
    {
        status = cudaStreamCreate(&stream_nx_exp);
        if (status != cudaSuccess)
        {
            printf("cudaStreamCreate failed for stream_nx_exp\n");
            fflush(stdout);
            return 1; 
        }
        status = cudaStreamCreate(&stream_ny_exp);
        if (status != cudaSuccess)
        {
            printf("cudaStreamCreate failed for stream_ny_exp\n");
            fflush(stdout);
            return 1; 
        }

        // compute max/min 
        computeMax<<<block_count_pins, thread_count, 0, stream_x_exp>>>(
                x, 
                pin2net_map, 
                net_mask, 
                num_nets, 
                num_pins, 
                xy_max
                );
        computeMin<<<block_count_pins, thread_count, 0, stream_nx_exp>>>(
                x, 
                pin2net_map, 
                net_mask, 
                num_nets, 
                num_pins, 
                xy_min
                );
        computeMax<<<block_count_pins, thread_count, 0, stream_y_exp>>>(
                y, 
                pin2net_map, 
                net_mask, 
                num_nets, 
                num_pins, 
                xy_max+num_nets
                );
        computeMin<<<block_count_pins, thread_count, 0, stream_ny_exp>>>(
                y, 
                pin2net_map, 
                net_mask, 
                num_nets, 
                num_pins, 
                xy_min+num_nets
                );

        // compute exp and negative exp 
        computeExp<<<block_count_pins, thread_count, 0, stream_x_exp>>>(
                x, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                xy_max, 
                exp_xy
                );
        computeNegExp<<<block_count_pins, thread_count, 0, stream_nx_exp>>>(
                x, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                xy_min, 
                exp_nxy
                );
        computeExp<<<block_count_pins, thread_count, 0, stream_y_exp>>>(
                y, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                xy_max+num_nets, 
                exp_xy+num_pins
                );
        computeNegExp<<<block_count_pins, thread_count, 0, stream_ny_exp>>>(
                y, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                gamma, 
                xy_min+num_nets, 
                exp_nxy+num_pins
                );

        // compute exp sum 
        computeExpSum<<<block_count_pins, thread_count, 0, stream_x_exp>>>(
                exp_xy, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                exp_xy_sum
                );
        computeExpSum<<<block_count_pins, thread_count, 0, stream_nx_exp>>>(
                exp_nxy, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                exp_nxy_sum
                );
        computeExpSum<<<block_count_pins, thread_count, 0, stream_y_exp>>>(
                exp_xy+num_pins, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                exp_xy_sum+num_nets
                );
        computeExpSum<<<block_count_pins, thread_count, 0, stream_ny_exp>>>(
                exp_nxy+num_pins, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                exp_nxy_sum+num_nets
                );

        // compute x exp sum 
        computeXExpSum<<<block_count_pins, thread_count, 0, stream_x_exp>>>(
                x, 
                exp_xy, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                xyexp_xy_sum
                );
        computeXExpSum<<<block_count_pins, thread_count, 0, stream_nx_exp>>>(
                x, 
                exp_nxy, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                xyexp_nxy_sum
                );
        computeXExpSum<<<block_count_pins, thread_count, 0, stream_y_exp>>>(
                y, 
                exp_xy+num_pins, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                xyexp_xy_sum+num_nets
                );
        computeXExpSum<<<block_count_pins, thread_count, 0, stream_ny_exp>>>(
                y, 
                exp_nxy+num_pins, 
                pin2net_map, 
                net_mask, 
                num_nets,
                num_pins, 
                xyexp_nxy_sum+num_nets
                );
        
        int block_count_nets = (num_nets - 1 + thread_count) / thread_count;
        // compute log sum exp 
        computeXExpSumByExpSum<<<block_count_nets, thread_count, 0, stream_x_exp>>>(
                xyexp_xy_sum, 
                exp_xy_sum, 
                pin2net_map, 
                net_mask, 
                num_nets,
                partial_wl
                );
        computeXNegExpSumByNegExpSum<<<block_count_nets, thread_count, 0, stream_nx_exp>>>(
                xyexp_nxy_sum, 
                exp_nxy_sum, 
                pin2net_map, 
                net_mask, 
                num_nets,
                partial_wl+num_nets
                );

        computeXExpSumByExpSum<<<block_count_nets, thread_count, 0, stream_y_exp>>>(
                xyexp_xy_sum+num_nets, 
                exp_xy_sum+num_nets, 
                pin2net_map, 
                net_mask, 
                num_nets,
                partial_wl+2*num_nets
                );
        computeXNegExpSumByNegExpSum<<<block_count_nets, thread_count, 0, stream_ny_exp>>>(
                xyexp_nxy_sum+num_nets, 
                exp_nxy_sum+num_nets, 
                pin2net_map, 
                net_mask, 
                num_nets,
                partial_wl+3*num_nets
                );

        // I move out the summation to use ATen 
        // significant speedup is observed 
        //sumArray<<<1, 1>>>(partial_wl, 2*num_nets, wl);

        status = cudaStreamDestroy(stream_nx_exp); 
        stream_nx_exp = 0;
        if (status != cudaSuccess) 
        {
            printf("stream_nx_exp destroy failed\n");
            fflush(stdout);
            return 1;
        }   
        status = cudaStreamDestroy(stream_ny_exp); 
        stream_ny_exp = 0; 
        if (status != cudaSuccess) 
        {
            printf("stream_ny_exp destroy failed\n");
            fflush(stdout);
            return 1;
        }   
    }

    /* destroy stream */
    status = cudaStreamDestroy(stream_x_exp); 
    stream_x_exp = 0;
    if (status != cudaSuccess) 
    {
        printf("stream_x_exp destroy failed\n");
        fflush(stdout);
        return 1;
    }   
    status = cudaStreamDestroy(stream_y_exp); 
    stream_y_exp = 0; 
    if (status != cudaSuccess) 
    {
        printf("stream_y_exp destroy failed\n");
        fflush(stdout);
        return 1;
    }   

    return 0; 
}


#define REGISTER_KERNEL_LAUNCHER(T, V) \
    int instantiateComputeWeightedAverageWirelengthAtomicLauncher(\
            const T* x, const T* y, \
            const int* pin2net_map, \
            const unsigned char* net_mask, \
            int num_nets, \
            int num_pins, \
            const T* gamma, \
            T* exp_xy, T* exp_nxy, \
            T* exp_xy_sum, T* exp_nxy_sum,\
            T* xyexp_xy_sum, T* xyexp_nxy_sum, \
            V* xy_max, V* xy_min, \
            T* partial_wl, \
            const T* grad_tensor, \
            T* grad_x_tensor, T* grad_y_tensor \
            )\
    {\
        return computeWeightedAverageWirelengthCudaAtomicLauncher(\
                x, y, \
                pin2net_map, \
                net_mask, \
                num_nets,\
                num_pins,\
                gamma, \
                exp_xy, exp_nxy, \
                exp_xy_sum, exp_nxy_sum, \
                xyexp_xy_sum, xyexp_nxy_sum, \
                xy_max, xy_min, \
                partial_wl, \
                grad_tensor, \
                grad_x_tensor, grad_y_tensor  \
                );\
    }
REGISTER_KERNEL_LAUNCHER(float, int);
REGISTER_KERNEL_LAUNCHER(double, int);

DREAMPLACE_END_NAMESPACE
