import sys

def test_multiresolutionimageinterface():
    import multiresolutionimageinterface
    print("multiresolutionimageinterface test passed")

def test_pyvips():
    import pyvips
    print("pyvips test passed")

def test_opencv():
    import cv2
    print("OpenCV test passed")

def test_numpy():
    import numpy as np
    assert np.array([1, 2, 3]).sum() == 6
    print("Numpy test passed")

def test_scipy():
    import scipy
    print("SciPy test passed")

def test_pytorch():
    import torch
    try:
        assert torch.cuda.is_available(), "GPU not available."
    except AssertionError:
        print("Warning: GPU not available, testing on CPU.")
    # Simple PyTorch computation to test CPU functionality
    x = torch.rand(5, 3)
    print("PyTorch CPU test passed with tensor:", x)

def test_tensorflow():
    import tensorflow as tf
    if not tf.test.is_gpu_available():
        print("Warning: GPU not available, testing on CPU.")
    # Simple TensorFlow computation to test CPU functionality
    x = tf.random.uniform([5, 3])
    print("TensorFlow CPU test passed with tensor:", x.numpy())

def test_pytorch_lightning():
    import pytorch_lightning
    print("PyTorch Lightning test passed")


def run_tests(stage):
    if stage == "base-cpu":
        test_multiresolutionimageinterface()
        test_pyvips()
        test_opencv()
        test_numpy()
        test_scipy()

    elif stage == "pytorch":
        test_pytorch()
        test_pytorch_lightning()

    elif stage == "tensorflow":
        test_tensorflow()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_tests(sys.argv[1])
    else:
        print("Please specify the stage to test.")
